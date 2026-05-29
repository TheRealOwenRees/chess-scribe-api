open Lwt.Syntax
open Yojson.Safe.Util
open Pgn_logic

let tex_start = "\\begin{document}\\begin{multicols}{2}"
let tex_end = "\\end{multicols}\\end{document}"

let handle_convert request =
  let temp_id =
    Int64.to_string (Int64.of_float (Unix.gettimeofday () *. 1000.0))
  in

  let temp_dir = Filename.get_temp_dir_name () in

  let tex_file_path =
    Filename.concat temp_dir (Printf.sprintf "game-%s.tex" temp_id)
  in

  let pdf_file_path =
    Filename.concat temp_dir (Printf.sprintf "game-%s.pdf" temp_id)
  in

  let log_file_path =
    Filename.concat temp_dir (Printf.sprintf "game-%s.log" temp_id)
  in

  let aux_file_path =
    Filename.concat temp_dir (Printf.sprintf "game-%s.aux" temp_id)
  in

  let cleanup () =
    [ tex_file_path; pdf_file_path; log_file_path; aux_file_path ]
    |> List.iter (fun path -> if Sys.file_exists path then Sys.remove path)
  in

  let* body = Dream.body request in

  try
    let json = Yojson.Safe.from_string body in

    let pgn = json |> member "pgn" |> to_string in
    let diagram_clock = json |> member "diagramClock" |> to_bool in
    let diagrams_json = json |> member "diagrams" in

    let diagrams_data =
      Yojson.Safe.to_string diagrams_json |> Pgn2tex.parse_diagrams_json
    in

    let game_tex =
      tex_start
      ^ Pgn2tex.to_tex pgn ~diagram_data:diagrams_data ~clock:diagram_clock
      ^ tex_end
    in

    Out_channel.with_open_text tex_file_path (fun oc ->
        Out_channel.output_string oc game_tex);

    let argv =
      [|
        "pdflatex";
        "-fmt";
        "./preambles/chess";
        "-interaction=nonstopmode";
        Printf.sprintf "-output-directory=%s" temp_dir;
        tex_file_path;
      |]
    in

    let pid =
      Unix.create_process "pdflatex" argv Unix.stdin Unix.stdout Unix.stderr
    in
    (* let _, process_status = Unix.waitpid [] pid in *)
    let _, _ = Unix.waitpid [] pid in

    if Sys.file_exists pdf_file_path then (
      let pdf_content =
        In_channel.with_open_bin pdf_file_path In_channel.input_all
      in

      cleanup ();

      (* TODO: record_metrics "SUCCESS" start_time; *)
      Dream.respond ~status:`Created
        ~headers:
          [
            ("Content-Disposition", "inline");
            ("Content-Type", "application/pdf");
          ]
        pdf_content)
    else failwith "PDF generation failed: output file not found on disk"
  with
  | Type_error (msg, _) ->
      cleanup ();
      Dream.json ~status:`Bad_Request
        (Printf.sprintf
           {|{"type": "error", "message": "JSON structure error: %s"}|} msg)
  | Yojson.Json_error msg ->
      cleanup ();
      Dream.json ~status:`Bad_Request
        (Printf.sprintf
           {|{"type": "error", "message": "Invalid JSON syntax: %s"}|} msg)
  | exn ->
      cleanup ();
      let err_msg = Printexc.to_string exn in
      (* TODO: record_metrics "FAIL" start_time err_msg; *)
      (* TODO: logger.error err_msg; *)
      Dream.json ~status:`Internal_Server_Error
        (Printf.sprintf {|{"type": "error", "message": "%s"}|} err_msg)
