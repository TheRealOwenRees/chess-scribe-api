let () =
  Dream.run @@ Dream.logger
  @@ Dream.router
       [
         Dream.get "/" (fun _ -> Dream.html "API Docs");
         Dream.get "/health" (fun _ -> Dream.html "Health Check");
         Dream.get "/pdf" (fun _ -> Dream.html "Generate PDF");
       ]
