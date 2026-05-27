let () =
  Dream.run ~interface:"0.0.0.0" ~port:8080
  @@ Dream.logger
  @@ Dream.router
       [
         Dream.get "/health" (fun _ -> Dream.respond "OK");
         Dream.get "/api" (fun _ -> Dream.html "API Docs");
         Dream.get "/api/pdf" (fun _ -> Dream.html "Generate PDF");
       ]
