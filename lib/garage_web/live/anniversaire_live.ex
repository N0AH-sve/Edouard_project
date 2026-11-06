defmodule GarageWeb.AnniversaireLive do
  @moduledoc """
  Page affichée le jour de l'anniversaire du garagiste.

  Elle s'ouvre d'elle-même à la première visite de la journée, puis se
  laisse oublier : `anniversaire_vu_le` est marqué dès l'affichage.
  """
  use GarageWeb, :live_view

  alias Garage.Profil

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.nue flash={@flash}>
      <div class="relative overflow-hidden rounded-[1.75rem] bg-white p-10 text-center shadow-[0_18px_50px_-20px_rgba(15,23,42,0.25)]">
        <div
          class="pointer-events-none absolute inset-x-0 -top-24 h-48 bg-primary/10 blur-3xl"
          aria-hidden="true"
        />

        <div class="relative space-y-6">
          <div class="text-6xl" role="img" aria-label="Gâteau d'anniversaire">🎂</div>

          <div class="space-y-3">
            <h1 class="text-3xl font-bold tracking-tight text-secondary">
              Bel anniversaire&nbsp;!
            </h1>
            <p class="text-xl font-semibold">{@reglages.prenom} {@reglages.nom}</p>
            <p :if={@age} class="text-base-content/60">
              {@age} ans aujourd'hui
            </p>
          </div>

          <p class="mx-auto max-w-sm text-sm leading-relaxed text-base-content/70">
            Toute l'équipe de {@reglages.societe} vous souhaite une excellente
            journée. Les clients attendront bien cinq minutes.
          </p>

          <div class="flex justify-center gap-6 pt-2 text-3xl" aria-hidden="true">
            <span>🎉</span>
            <span>🥳</span>
            <span>🎁</span>
          </div>

          <div class="pt-4">
            <.link
              navigate={~p"/clients"}
              class="inline-flex items-center gap-2 rounded-full bg-primary px-6 py-3 text-sm font-semibold text-primary-content transition hover:bg-secondary"
            >
              Au travail <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>
        </div>
      </div>
    </Layouts.nue>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    reglages = Profil.get_reglages()

    # Marqué dès l'affichage : la page ne doit s'imposer qu'une fois
    # dans la journée, même si le garagiste recharge ou navigue.
    if reglages && Profil.anniversaire_aujourdhui?(reglages) && connected?(socket) do
      Profil.marquer_souhaite(reglages)
    end

    {:ok,
     socket
     |> assign(:page_title, "Bel anniversaire")
     |> assign(:reglages, reglages)
     |> assign(:age, reglages && reglages.date_naissance && Profil.age(reglages))}
  end
end
