class ChatsController < ApplicationController
  include ActionController::Live

  def stream
    question   = params.require(:question)
    repository = Repository.find(params[:id])

    response.headers["Content-Type"]      = "text/event-stream"
    response.headers["Cache-Control"]     = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    sse = ActionController::Live::SSE.new(response.stream)

    begin
      sse.write(turbo_append("chat-messages", "chats/components/user_message", question: question))
      sse.write(turbo_append("chat-messages", "chats/components/thinking"))

      components = QueryService.new(repository, question).call

      sse.write(turbo_remove("chat-thinking"))

      components.each do |comp|
        partial_name = comp[:component].delete_prefix("render_")
        input = comp[:input].transform_keys(&:to_sym)
        sse.write(turbo_append("chat-messages", "chats/components/#{partial_name}", **input))
      end
    rescue => e
      Rails.logger.error("Chat SSE error: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      sse.write(turbo_remove("chat-thinking"))
      sse.write(turbo_append("chat-messages", "chats/components/plain_answer",
                             content: "Sorry, an error occurred. Please try again."))
    ensure
      sse.write("", event: "done")
      sse.close
    end
  end

  private

  def turbo_append(target, partial, **locals)
    html = ApplicationController.render(partial: partial, locals: locals)
    %(<turbo-stream action="append" target="#{target}"><template>#{html}</template></turbo-stream>)
  end

  def turbo_remove(target)
    %(<turbo-stream action="remove" target="#{target}"></turbo-stream>)
  end
end
