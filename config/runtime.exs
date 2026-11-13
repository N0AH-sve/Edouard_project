import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/garage start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :garage, GarageWeb.Endpoint, server: true
end

config :garage, GarageWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :garage, GarageWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Gettext translations
        ~r"priv/gettext/.*\.po$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/garage_web/router\.ex$"E,
        ~r"lib/garage_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /etc/garage/garage.db
      """

  config :garage,
         :uploads_dir,
         System.get_env("UPLOADS_DIR") ||
           raise("""
           la variable d'environnement UPLOADS_DIR est absente.
           Exemple : ~/Library/Application Support/Garage/uploads
           """)

  config :garage, Garage.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5"),
    # WAL : lecteurs et rédacteur ne se bloquent pas mutuellement.
    journal_mode: :wal,
    # Sans cela SQLite renvoie SQLITE_BUSY immédiatement. La sauvegarde
    # quotidienne lit la base pendant que l'application peut écrire :
    # on préfère attendre 5 s plutôt qu'échouer.
    busy_timeout: 5_000,
    # Durabilité raisonnable en WAL sans fsync à chaque transaction.
    synchronous: :normal,
    # Les clés étrangères ne sont pas optionnelles : elles font tenir
    # les contraintes :restrict des migrations.
    foreign_keys: :on

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :garage, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :garage, GarageWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Boucle locale UNIQUEMENT.
      #
      # Phoenix propose par défaut {0, 0, 0, 0, 0, 0, 0, 0}, c'est-à-dire
      # toutes les interfaces. Ce serait ici une faute : l'application n'a
      # ni comptes ni authentification, et cette absence n'est justifiable
      # que parce qu'elle est injoignable depuis le réseau. Sur le wifi du
      # garage, le fichier clients serait ouvert à tout le monde.
      #
      # Lier la boucle locale évite aussi la fenêtre du pare-feu macOS
      # « autoriser les connexions entrantes ».
      ip: {127, 0, 0, 1}
    ],

    # « localhost » et « 127.0.0.1 » désignent la même machine mais sont
    # deux chaînes différentes : Phoenix compare l'en-tête Origin du
    # websocket à PHX_HOST, et refuse l'autre forme avec un 403. La page
    # s'afficherait alors sans que rien ne fonctionne — ni recherche, ni
    # formulaire, ni téléversement. On accepte donc les deux.
    check_origin: ["//localhost", "//127.0.0.1"],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :garage, GarageWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :garage, GarageWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
