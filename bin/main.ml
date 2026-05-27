let () =
  Dream.run ~interface:"0.0.0.0" ~port:8080
  @@ Dream.logger
  @@ Dream.router
       [
         Dream.get "/" (fun _ -> Dream.html "API Docs");
         Dream.get "/health" (fun _ -> Dream.html "Health Check");
         Dream.get "/pdf" (fun _ -> Dream.html "Generate PDF");
       ]
