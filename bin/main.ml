open Lwt.Syntax
open Yojson.Safe.Util
open Pgn_logic

let allowed_origins =
  [
    "https://chess-scribe.org";
    "https://www.chess-scribe.org";
    "http://localhost:3000";
  ]

let is_dev_mode () =
  Array.to_list Sys.argv
  |> List.exists (fun arg -> arg = "DREAM_ENV=development")

let cors_middleware next_handler request =
  let allowed_origin =
    if is_dev_mode () then "*"
    else
      match Dream.header request "Origin" with
      | Some origin when List.mem origin allowed_origins -> origin
      | _ -> "https://chess-scribe.org"
  in

  if Dream.method_ request = `OPTIONS then (
    let response = Dream.response "" in
    Dream.add_header response "Access-Control-Allow-Origin" allowed_origin;
    Dream.add_header response "Access-Control-Allow-Methods"
      "POST, GET, OPTIONS";
    Dream.add_header response "Access-Control-Allow-Headers"
      "Content-Type, Authorization";
    Dream.add_header response "Access-Control-Max-Age" "86400";
    Dream.set_status response `No_Content;
    Lwt.return response)
  else
    let* response = next_handler request in
    Dream.add_header response "Access-Control-Allow-Origin" allowed_origin;
    Lwt.return response

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
      "\\begin{document}\\begin{multicols}{2}"
      ^ Pgn2tex.to_tex pgn ~diagram_data:diagrams_data ~clock:diagram_clock
      ^ "\\end{multicols}\\end{document}"
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

let () =
  Dream.run ~interface:"0.0.0.0" ~port:8080
  @@ Dream.logger @@ cors_middleware
  @@ Dream.router
       [
         Dream.get "/" (fun request ->
             Dream.from_filesystem "static" "doc.html" request);
         Dream.get "/health" (fun _ -> Dream.respond "OK");
         Dream.post "/api/v1/pdf" handle_convert;
         Dream.get "/api/v1" (fun request ->
             Dream.from_filesystem "static" "doc.html" request);
         Dream.get "/swagger.json" (fun request ->
             Dream.from_filesystem "static" "swagger.json" request);
       ]
