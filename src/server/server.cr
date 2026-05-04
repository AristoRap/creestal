require "http/server"
require "mime"

module Creestal
  module Server
    RELOAD_SCRIPT = %(<script>(()=>{const s=new EventSource('/__live_reload');const c=()=>s.close();s.onmessage=()=>{c();location.reload()};s.onerror=()=>{};window.addEventListener('pagehide',c,{once:true});window.addEventListener('beforeunload',c,{once:true});})();</script>)

    class Server
      @http_server : HTTP::Server?
      @reload_channels : Array(Channel(Nil))
      @clients_mutex : Mutex

      def initialize(
        @root : String,
        @home : String,
        @host : String = Creestal::DEFAULT_HOST,
        @port : Int32 = Creestal::DEFAULT_PORT,
        @watch : Bool = false,
      )
        @http_server = nil
        @reload_channels = [] of Channel(Nil)
        @clients_mutex = Mutex.new
      end

      def start : Nil
        router = Router.new(@root, @home)
        @http_server = HTTP::Server.new do |context|
          handle_request(context, router)
        end
        @http_server.not_nil!.bind_tcp(@host, @port)
        @http_server.not_nil!.listen
      end

      def stop : Nil
        @http_server.try &.close
      end

      def broadcast_reload : Nil
        channels = [] of Channel(Nil)
        @clients_mutex.synchronize do
          channels = @reload_channels.dup
          @reload_channels.clear
        end
        channels.each { |ch| ch.send(nil) rescue nil }
      end

      private def handle_request(context : HTTP::Server::Context, router : Router)
        if context.request.path == "/__live_reload"
          handle_sse(context)
          return
        end

        file_path = router.resolve_request(context.request.path)
        if !file_path.empty? && File.exists?(file_path) && !File.directory?(file_path)
          serve_file(context, file_path)
        else
          not_found(context)
        end
      end

      private def handle_sse(context : HTTP::Server::Context)
        res = context.response
        res.headers["Content-Type"] = "text/event-stream"
        res.headers["Cache-Control"] = "no-cache"
        res.headers["X-Accel-Buffering"] = "no"

        ch = Channel(Nil).new(1)
        @clients_mutex.synchronize { @reload_channels << ch }
        ch.receive
        res.print("data: reload\n\n")
      end

      private def serve_file(context : HTTP::Server::Context, file_path : String)
        context.response.status_code = 200
        context.response.content_type = content_type_for(file_path)

        if @watch && file_path.ends_with?(".html")
          html = Utils::FS.read_file(file_path)
          content = html.includes?("</body>") ? html.sub("</body>", "#{RELOAD_SCRIPT}</body>") : html + RELOAD_SCRIPT
          context.response.print(content)
        else
          File.open(file_path) { |f| IO.copy(f, context.response) }
        end
      rescue IO::Error
        not_found(context)
      end

      private def not_found(context : HTTP::Server::Context)
        context.response.status_code = 404
        context.response.content_type = "text/plain; charset=utf-8"
        context.response.print("Not Found")
      end

      private def content_type_for(file_path : String) : String
        case File.extname(file_path).downcase
        when ".html"         then "text/html; charset=utf-8"
        when ".css"          then "text/css; charset=utf-8"
        when ".js"           then "application/javascript; charset=utf-8"
        when ".json"         then "application/json; charset=utf-8"
        when ".svg"          then "image/svg+xml"
        when ".png"          then "image/png"
        when ".jpg", ".jpeg" then "image/jpeg"
        when ".gif"          then "image/gif"
        when ".webp"         then "image/webp"
        when ".txt"          then "text/plain; charset=utf-8"
        else                      "application/octet-stream"
        end
      end
    end
  end
end
