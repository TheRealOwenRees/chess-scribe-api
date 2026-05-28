open Lwt.Syntax
open Yojson.Safe.Util
open Pgn_logic

let is_dev_mode () =
  Array.to_list Sys.argv
  |> List.exists (fun arg -> arg = "DREAM_ENV=development")

let cors_middleware next_handler request =
  let allowed_origin =
    if is_dev_mode () then "*" else "https://chess-scribe.org"
  in

  if Dream.method_ request = `OPTIONS then (
    let response = Dream.response "" in
    Dream.add_header response "Access-Control-Allow-Origin" allowed_origin;
    Dream.add_header response "Access-Control-Allow-Methods" "POST, GET";
    Dream.add_header response "Access-Control-Allow-Headers"
      "Content-Type, Authorization";
    Dream.set_status response `No_Content;
    Lwt.return response)
  else
    let* response = next_handler request in
    Dream.add_header response "Access-Control-Allow-Origin" allowed_origin;
    Lwt.return response

let handle_convert request =
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
      Pgn2tex.to_tex pgn ~diagram_data:diagrams_data ~clock:diagram_clock
    in

    print_endline game_tex;

    Dream.json {|{"status": "ok", "message": "Payload parsed successfully!"}|}
  with
  | Type_error (msg, _) ->
      Dream.json ~status:`Bad_Request
        (Printf.sprintf
           {|{"type": "error", "message": "JSON structure error: %s"}|} msg)
  | Yojson.Json_error msg ->
      Dream.json ~status:`Bad_Request
        (Printf.sprintf
           {|{"type": "error", "message": "Invalid JSON syntax: %s"}|} msg)
  | exn ->
      Dream.json ~status:`Internal_Server_Error
        (Printf.sprintf {|{"type": "error", "message": "%s"}|}
           (Printexc.to_string exn))

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
