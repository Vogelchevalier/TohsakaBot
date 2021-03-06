module TohsakaBot
  module Events
    module SquadsMute
      extend Discordrb::EventContainer
      reaction_add(emoji: %w[❌ 🚫 🔕]) do |event|
        next if event.channel.pm? || event.user.bot_account
        next unless Time.now.to_i <= event.message.timestamp.to_i + 3600

        if event.user.id == event.message.author.id
          Discordrb::API::Channel.delete_user_reaction(
            "Bot #{AUTH.bot_token}", event.channel.id, event.message.id, event.emoji.name, event.message.author.id
          )
          next
        end

        role_ids = JSON.parse(File.read("data/persistent/squads.json")).values.collect { |role| role["role_id"].to_i }
        role_id = nil
        event.message.role_mentions.each do |rm|
          if role_ids.include? rm.id.to_i
            role_id = rm.id.to_i
            break
          end
        end
        next if role_id.nil?

        author_id = event.message.author.id.to_i
        next unless BOT.member(event.server.id, author_id).role?(role_id)

        durations = { "❌" => 1, "🚫" => 6, "🔕" => 24 }

        db = YAML::Store.new("data/squads_mute.yml")
        i = 1
        db.transaction do
          i += 1 while db.root?(i)
          db[i] = {
            'time' => Time.now,
            'hours' => durations[event.emoji.name],
            'user' => author_id,
            'server' => event.server.id,
            'role' => role_id
          }
          db.commit
        end

        Discordrb::API::Server.remove_member_role(
          "Bot #{AUTH.bot_token}",
          event.channel.server.id,
          author_id,
          role_id
        )
      end
    end
  end
end
