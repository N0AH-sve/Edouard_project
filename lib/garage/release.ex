defmodule Garage.Release do
  @moduledoc """
  Tâches exécutées depuis la release compilée, là où Mix n'existe plus.

  Appelé par l'installeur macOS :

      bin/garage eval "Garage.Release.migrate"
  """

  @app :garage

  @doc """
  Prépare les dossiers de données puis applique les migrations en attente.

  Exécuté à chaque installation et à chaque mise à jour : c'est ce qui
  garantit que la base d'un garagiste déjà en service est mise à niveau
  sans perdre une ligne.
  """
  def migrate do
    load_app()
    preparer_dossiers()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    :ok
  end

  @doc """
  Revient d'une version. À n'utiliser qu'en connaissance de cause.
  """
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  # La base et les PDF vivent dans « Application Support ». Au tout premier
  # lancement ces dossiers n'existent pas : SQLite ne les crée pas lui-même
  # et échouerait à ouvrir le fichier.
  defp preparer_dossiers do
    for repo <- repos(),
        path = repo.config()[:database],
        is_binary(path) do
      File.mkdir_p!(Path.dirname(path))
    end

    case System.get_env("UPLOADS_DIR") do
      nil -> :ok
      dir -> File.mkdir_p!(dir)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
