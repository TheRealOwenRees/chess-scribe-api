open Lwt.Syntax
open Yojson.Safe.Util
open Pgn_logic

let () =
  Dream.run ~interface:"0.0.0.0" ~port:8080
  @@ Dream.logger @@ Cors.middleware
  @@ Dream.router
       [
         Dream.get "/" (fun request ->
             Dream.from_filesystem "static" "doc.html" request);
         Dream.get "/health" (fun _ ->
             Dream.json {|{"type": "success", "message": "API is functional"}|});
         Dream.post "/api/v1/pdf" Pdf_handler.handle_convert;
         Dream.get "/api/v1" (fun request ->
             Dream.from_filesystem "static" "doc.html" request);
         Dream.get "/swagger.json" (fun request ->
             Dream.from_filesystem "static" "swagger.json" request);
       ]
