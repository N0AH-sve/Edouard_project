defmodule GarageWeb.Layouts do
  @moduledoc """
  Coquille visuelle de l'application.

  La mise en page suit la maquette fournie : barre latérale d'icônes à
  gauche, en-tête avec recherche, onglets au-dessus du contenu, et tout
  l'ensemble posé dans une grande carte blanche arrondie sur fond clair.
  """
  use GarageWeb, :html

  embed_templates "layouts/*"

  @nav [
    %{cle: :clients, libelle: "Clients", icone: "hero-users", chemin: "/clients"},
    %{cle: :vehicules, libelle: "Véhicules", icone: "hero-truck", chemin: "/vehicules"},
    %{
      cle: :interventions,
      libelle: "Interventions",
      icone: "hero-wrench-screwdriver",
      chemin: "/interventions"
    }
  ]

  @doc """
  Gabarit principal.

  `actif` indique l'entrée de navigation à mettre en évidence.
  L'emplacement `onglets` reçoit les filtres de la page, `actions` les
  boutons alignés à droite de la barre de recherche.
  """
  attr :flash, :map, required: true
  attr :reglages, :map, default: nil
  attr :titre, :string, default: "Garage"
  attr :actif, :atom, default: nil
  attr :recherche, :string, default: nil
  attr :placeholder_recherche, :string, default: "Rechercher"

  slot :onglets
  slot :actions
  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign(assigns, :nav, @nav)

    ~H"""
    <div class="flex min-h-screen flex-col p-4 sm:p-6 lg:p-8">
      <div class="mx-auto flex w-full max-w-[1400px] flex-1 flex-col overflow-hidden rounded-[1.75rem] bg-white shadow-[0_18px_50px_-20px_rgba(15,23,42,0.25)]">
        <%!-- En-tête --%>
        <header class="flex items-center gap-4 border-b border-base-300 px-5 py-4">
          <.link navigate={~p"/clients"} class="flex items-center gap-3">
            <span class="grid size-9 place-items-center rounded-xl bg-primary text-primary-content">
              <.icon name="hero-wrench-screwdriver" class="size-5" />
            </span>
            <span class="text-lg font-bold tracking-tight">{@titre}</span>
          </.link>

          <div class="ml-auto flex items-center gap-3">
            <form
              :if={@recherche != nil}
              id="formulaire-recherche"
              phx-change="rechercher"
              phx-submit="rechercher"
            >
              <label class="flex w-64 items-center gap-2 rounded-full border border-base-300 bg-base-200 px-4 py-2 focus-within:border-primary lg:w-80">
                <.icon name="hero-magnifying-glass" class="size-4 text-base-content/40" />
                <input
                  type="search"
                  name="q"
                  value={@recherche}
                  phx-debounce="200"
                  placeholder={@placeholder_recherche}
                  class="w-full bg-transparent text-sm outline-none placeholder:text-base-content/40"
                />
              </label>
            </form>

            <.link
              navigate={~p"/reglages"}
              title="Mon profil"
              class="grid size-9 place-items-center rounded-full border border-base-300 text-base-content/60 hover:border-primary hover:text-primary"
            >
              <.icon name="hero-user" class="size-4" />
            </.link>
          </div>
        </header>

        <div class="flex min-h-0 flex-1">
          <%!-- Barre latérale --%>
          <aside class="hidden w-16 shrink-0 flex-col items-center gap-1 border-r border-base-300 py-5 sm:flex">
            <.link
              :for={item <- @nav}
              navigate={item.chemin}
              title={item.libelle}
              aria-current={item.cle == @actif && "page"}
              class={[
                "grid size-10 place-items-center rounded-xl transition",
                item.cle == @actif &&
                  "bg-primary/10 text-primary ring-1 ring-primary/20",
                item.cle != @actif && "text-base-content/40 hover:bg-base-200 hover:text-base-content"
              ]}
            >
              <.icon name={item.icone} class="size-5" />
            </.link>

            <div
              :if={@reglages}
              class="mt-auto grid size-9 place-items-center rounded-full bg-secondary text-xs font-bold text-secondary-content"
              title={"#{@reglages.prenom} #{@reglages.nom}"}
            >
              {initiales(@reglages)}
            </div>
          </aside>

          <%!-- Contenu --%>
          <div class="flex min-w-0 flex-1 flex-col bg-base-200/60">
            <div :if={@onglets != []} class="flex gap-1 px-5 pt-4">
              {render_slot(@onglets)}
            </div>

            <div class="flex min-h-0 flex-1 flex-col p-5">
              <div class="flex min-h-0 flex-1 flex-col rounded-2xl border border-base-300 bg-white">
                <div
                  :if={@actions != []}
                  class="flex flex-wrap items-center justify-end gap-3 border-b border-base-300 px-5 py-4"
                >
                  {render_slot(@actions)}
                </div>

                {render_slot(@inner_block)}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Un onglet de filtre, avec son compteur. Cf. maquette.
  """
  attr :navigate, :string, required: true
  attr :icone, :string, default: nil
  attr :actif, :boolean, default: false
  attr :compteur, :integer, default: nil
  slot :inner_block, required: true

  def onglet(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center gap-2 rounded-t-xl px-4 py-2.5 text-sm transition",
        @actif && "bg-white font-semibold text-base-content shadow-[0_-1px_0_0_var(--color-2)_inset]",
        !@actif && "text-base-content/50 hover:text-base-content"
      ]}
    >
      <.icon :if={@icone} name={@icone} class="size-4" />
      {render_slot(@inner_block)}
      <span
        :if={@compteur}
        class={[
          "rounded-full px-2 py-0.5 text-xs font-semibold",
          @actif && "bg-primary text-primary-content",
          !@actif && "bg-base-300 text-base-content/60"
        ]}
      >
        {@compteur}
      </span>
    </.link>
    """
  end

  @doc """
  Barre d'actions flottante, affichée dès qu'une ligne est cochée.
  """
  attr :nombre, :integer, required: true
  slot :inner_block, required: true

  def barre_selection(assigns) do
    ~H"""
    <div
      :if={@nombre > 0}
      class="fixed inset-x-0 bottom-6 z-40 flex justify-center px-4"
      role="region"
      aria-label="Actions groupées"
    >
      <div class="flex items-center gap-3 rounded-full bg-neutral px-4 py-3 text-neutral-content shadow-[0_18px_40px_-12px_rgba(15,23,42,0.6)]">
        <button
          type="button"
          phx-click="tout_deselectionner"
          title="Annuler la sélection"
          class="grid size-7 place-items-center rounded-full text-neutral-content/60 hover:bg-white/10 hover:text-neutral-content"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>

        <span class="flex items-center gap-2 pr-2 text-sm">
          <span class="grid min-w-7 place-items-center rounded-full bg-white/15 px-2 py-0.5 font-semibold">
            {@nombre}
          </span>
          <span class="hidden sm:inline">
            {if @nombre > 1, do: "éléments sélectionnés", else: "élément sélectionné"}
          </span>
        </span>

        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Bouton de la barre d'actions flottante.
  """
  attr :danger, :boolean, default: false
  attr :rest, :global, include: ~w(phx-click phx-value-id data-confirm type title)
  slot :inner_block, required: true

  def bouton_barre(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "flex items-center gap-2 rounded-full px-4 py-2 text-sm font-medium transition",
        @danger && "bg-error text-error-content hover:brightness-110",
        !@danger && "bg-white/10 text-neutral-content hover:bg-white/20"
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Écran autonome, sans navigation : premier démarrage, anniversaire.
  """
  attr :flash, :map, required: true
  slot :inner_block, required: true

  def nue(assigns) do
    ~H"""
    <main class="flex min-h-screen items-center justify-center px-4 py-10">
      <div class="w-full max-w-lg">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  defp initiales(%{prenom: p, nom: n}) do
    String.upcase(String.first(p || "") <> String.first(n || ""))
  end

  @doc """
  Bandeau des messages flash.
  """
  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="Connexion perdue"
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Tentative de reconnexion
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Une erreur est survenue"
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Tentative de reconnexion
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
