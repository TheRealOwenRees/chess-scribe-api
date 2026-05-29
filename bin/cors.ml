let allowed_origins =
  [
    "https://chess-scribe.org";
    "https://www.chess-scribe.org";
    "http://localhost:3000";
  ]

let is_dev_mode () =
  Array.to_list Sys.argv
  |> List.exists (fun arg -> arg = "DREAM_ENV=development")

let middleware next_handler request =
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
    let open Lwt.Syntax in
    let* response = next_handler request in
    Dream.add_header response "Access-Control-Allow-Origin" allowed_origin;
    Lwt.return response
