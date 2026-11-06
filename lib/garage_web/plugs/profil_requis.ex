defmodule GarageWeb.ProfilRequis do
  @moduledoc """
  Porte d'entrée de l'application.

  Tant que le profil du garagiste n'a pas été saisi, toute visite est
  renvoyée vers l'écran de bienvenue. Une fois saisi, l'écran de bienvenue
  n'est plus accessible.

  Deux mécanismes sont nécessaires :

    * `call/2` — un plug, pour la première requête HTTP ;
    * `on_mount/4` — un hook LiveView, car la navigation `live_redirect`
      ne repasse pas par les plugs après le montage initial. Sans lui, un
      lien interne permettrait de contourner la vérification.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias Garage.Profil

  @accueil "/bienvenue"
  @principal "/clients"
  @anniversaire "/anniversaire"

  # --- Plug (requêtes HTTP) --------------------------------------------------

  def init(opts), do: opts

  def call(conn, _opts) do
    cond do
      not Profil.configure?() ->
        conn |> redirect(to: @accueil) |> halt()

      Profil.souhaiter?(Profil.get_reglages()) ->
        conn |> redirect(to: @anniversaire) |> halt()

      true ->
        conn
    end
  end

  @doc """
  Plug inverse : interdit l'écran de bienvenue une fois le profil saisi.
  """
  def rediriger_si_configure(conn, _opts) do
    if Profil.configure?() do
      conn
      |> redirect(to: @principal)
      |> halt()
    else
      conn
    end
  end

  # --- Hook LiveView --------------------------------------------------------

  def on_mount(:exiger_profil, _params, _session, socket) do
    case charger_reglages() do
      nil ->
        {:halt, Phoenix.LiveView.redirect(socket, to: @accueil)}

      reglages ->
        if Profil.souhaiter?(reglages) do
          {:halt, Phoenix.LiveView.redirect(socket, to: @anniversaire)}
        else
          {:cont, Phoenix.Component.assign(socket, :reglages, reglages)}
        end
    end
  end

  @doc """
  La page d'anniversaire exige un profil, mais pas d'être le jour J :
  le garagiste peut la rouvrir s'il le souhaite.
  """
  def on_mount(:anniversaire, _params, _session, socket) do
    case charger_reglages() do
      nil -> {:halt, Phoenix.LiveView.redirect(socket, to: @accueil)}
      reglages -> {:cont, Phoenix.Component.assign(socket, :reglages, reglages)}
    end
  end

  def on_mount(:interdire_si_configure, _params, _session, socket) do
    if Profil.configure?() do
      {:halt, Phoenix.LiveView.redirect(socket, to: @principal)}
    else
      {:cont, socket}
    end
  end

  defp charger_reglages, do: Profil.get_reglages()
end
