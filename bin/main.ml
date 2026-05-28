open Lwt.Syntax
open Yojson.Safe.Util

let is_dev_mode () =
  Array.to_list Sys.argv
  |> List.exists (fun arg -> arg = "DREAM_ENV=development")

(* Custom CORS Middleware *)
let cors_middleware next_handler request =
  let allowed_origin =
    if is_dev_mode () then "*" else "https://chess-scribe.org"
  in

  if Dream.method_ request = `OPTIONS then (
    let response = Dream.response "" in
    Dream.add_header response "Access-Control-Allow-Origin" allowed_origin;
    Dream.add_header response "Access-Control-Allow-Methods"
      "POST, GET, OPTIONS";
    Dream.add_header response "Access-Control-Allow-Headers"
      "Content-Type, Authorization";
    Dream.set_status response `No_Content;
    Lwt.return response)
  else
    (* 3. Pass normal requests through and append the origin header *)
    let* response = next_handler request in
    Dream.add_header response "Access-Control-Allow-Origin" allowed_origin;
    Lwt.return response

let handle_convert request =
  let* body = Dream.body request in

  try
    let json = Yojson.Safe.from_string body in

    let pgn = json |> member "pgn" |> to_string in
    let diagram_clock = json |> member "diagramClock" |> to_bool in

    (* For diagrams, we grab the raw sub-tree as a string to pass along later *)
    let diagrams_json = json |> member "diagrams" in
    let diagrams_str = Yojson.Safe.to_string diagrams_json in

    print_endline "\n--- Received Request ---";
    Printf.printf "PGN:\n%s\n\n" pgn;
    Printf.printf "Diagrams JSON String: %s\n" diagrams_str;
    Printf.printf "Diagram Clock: %b\n" diagram_clock;
    print_endline "------------------------\n";

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
         (* Health check (Exact match) *)
         Dream.get "/health" (fun _ -> Dream.respond "OK");
         (* Specific API Endpoints (Must be ABOVE the wildcard) *)
         Dream.post "/api/v1/pdf" handle_convert;
         (* Exact match for the docs root *)
         Dream.get "/api/v1" (fun request ->
             Dream.from_filesystem "static" "doc.html" request);
         (* Dedicated route for swagger.json if accessed outside /api/ *)
         Dream.get "/swagger.json" (fun request ->
             Dream.from_filesystem "static" "swagger.json" request);
       ]
