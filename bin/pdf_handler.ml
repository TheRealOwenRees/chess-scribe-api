open Lwt.Syntax
open Yojson.Safe.Util
open Pgn_to_tex

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
    let parsed = Chess_scribe_api.Request.parse body in

    let game_tex =
      tex_start
      ^ Pgn_to_tex.to_tex ~diagram_data:parsed.diagrams ~clock:parsed.clock
          parsed.pgn
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

    let dev_null = Unix.openfile Filename.null [ Unix.O_WRONLY ] 0o600 in
    let pid =
      Unix.create_process "pdflatex" argv Unix.stdin dev_null dev_null
    in
    let _, _ = Unix.waitpid [] pid in
    Unix.close dev_null;

    if Sys.file_exists pdf_file_path then (
      let pdf_content =
        In_channel.with_open_bin pdf_file_path In_channel.input_all
      in

      cleanup ();

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
      Dream.log "PDF conversion failed: %s" (Printexc.to_string exn);
      Dream.json ~status:`Internal_Server_Error
        {|{"type": "error", "message": "Internal server error"}|}
