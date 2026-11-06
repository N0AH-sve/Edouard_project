defmodule GarageWeb.VehiculeLive.Index do
  @moduledoc "Liste des véhicules, cherchables par plaque."
  use GarageWeb, :live_view

  alias Garage.Atelier
  alias Garage.Atelier.Client
  alias Garage.Atelier.Vehicule

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      reglages={@reglages}
      titre="Véhicules"
      actif={:vehicules}
      recherche={@recherche}
      placeholder_recherche="Immatriculation, marque, client…"
    >
      <:onglets>
        <Layouts.onglet
          navigate={~p"/vehicules"}
          icone="hero-truck"
          actif={@filtre == :tous}
          compteur={@total}
        >
          Tous les véhicules
        </Layouts.onglet>
        <Layouts.onglet
          navigate={~p"/vehicules?filtre=ct"}
          icone="hero-exclamation-triangle"
          actif={@filtre == :ct}
          compteur={@total_ct}
        >
          Contrôle technique à prévoir
        </Layouts.onglet>
      </:onglets>

      <:actions>
        <.link
          navigate={~p"/vehicules/nouveau"}
          class="inline-flex items-center gap-2 rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-content transition hover:bg-secondary"
        >
          <.icon name="hero-plus" class="size-4" /> Nouveau véhicule
        </.link>
      </:actions>

      <div :if={@vehicules == []} class="px-6 py-16 text-center">
        <.icon name="hero-truck" class="mx-auto size-10 text-base-content/20" />
        <p class="mt-4 font-medium">Aucun véhicule à afficher.</p>
      </div>

      <div :if={@vehicules != []} class="overflow-x-auto">
        <table class="table-garage w-full text-left">
          <thead>
            <tr>
              <th class="w-12 pl-5">
                <input
                  type="checkbox"
                  class="checkbox checkbox-sm checkbox-primary"
                  checked={@tout_coche}
                  phx-click="basculer_tout"
                  aria-label="Tout sélectionner"
                />
              </th>
              <th>Immatriculation</th>
              <th>Véhicule</th>
              <th>Propriétaire</th>
              <th class="text-right">Kilométrage</th>
              <th>Prochain CT</th>
              <th class="w-12"></th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={v <- @vehicules}
              class={[MapSet.member?(@selection, v.id) && "ligne-selectionnee"]}
            >
              <td class="pl-5">
                <input
                  type="checkbox"
                  class="checkbox checkbox-sm checkbox-primary"
                  checked={MapSet.member?(@selection, v.id)}
                  phx-click="basculer"
                  phx-value-id={v.id}
                  aria-label={"Sélectionner #{v.immatriculation}"}
                />
              </td>

              <td>
                <.link
                  navigate={~p"/vehicules/#{v}"}
                  class="rounded-md bg-base-200 px-2 py-1 font-mono text-xs font-semibold hover:bg-primary/10 hover:text-primary"
                >
                  {v.immatriculation}
                </.link>
              </td>

              <td>
                <span class="font-medium">
                  {[v.marque, v.modele] |> Enum.reject(&is_nil/1) |> Enum.join(" ")}
                </span>
                <p class="text-xs text-base-content/50">
                  {[v.annee, Vehicule.libelle_carburant(v.carburant)]
                  |> Enum.reject(&(&1 in [nil, "—"]))
                  |> Enum.join(" · ")}
                </p>
              </td>

              <td>
                <.link
                  :if={v.client}
                  navigate={~p"/clients/#{v.client}"}
                  class="hover:text-primary hover:underline"
                >
                  {Client.nom_complet(v.client)}
                </.link>
              </td>

              <td class="text-right tabular-nums">{kilometrage(v.kilometrage)}</td>

              <td>
                <span class={classe_ct(v.date_prochain_ct)}>{libelle_ct(v.date_prochain_ct)}</span>
              </td>

              <td class="pr-5 text-right">
                <.link
                  navigate={~p"/vehicules/#{v}/modifier"}
                  title="Modifier"
                  class="inline-grid size-8 place-items-center rounded-full text-base-content/40 hover:bg-base-200 hover:text-base-content"
                >
                  <.icon name="hero-pencil-square" class="size-4" />
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <Layouts.barre_selection nombre={MapSet.size(@selection)}>
        <Layouts.bouton_barre
          danger
          phx-click="supprimer_selection"
          data-confirm="Supprimer les véhicules sélectionnés ?"
        >
          <.icon name="hero-trash" class="size-4" /> Supprimer
        </Layouts.bouton_barre>
      </Layouts.barre_selection>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Véhicules")
     |> assign(:recherche, "")
     |> assign(:filtre, :tous)
     |> assign(:selection, MapSet.new())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filtre = if params["filtre"] == "ct", do: :ct, else: :tous
    {:noreply, socket |> assign(:filtre, filtre) |> charger()}
  end

  @impl true
  def handle_event("rechercher", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:recherche, q) |> assign(:selection, MapSet.new()) |> charger()}
  end

  def handle_event("basculer", %{"id" => id}, socket) do
    id = String.to_integer(id)

    selection =
      if MapSet.member?(socket.assigns.selection, id),
        do: MapSet.delete(socket.assigns.selection, id),
        else: MapSet.put(socket.assigns.selection, id)

    {:noreply, socket |> assign(:selection, selection) |> calculer_tout_coche()}
  end

  def handle_event("basculer_tout", _params, socket) do
    selection =
      if socket.assigns.tout_coche,
        do: MapSet.new(),
        else: MapSet.new(socket.assigns.vehicules, & &1.id)

    {:noreply, socket |> assign(:selection, selection) |> calculer_tout_coche()}
  end

  def handle_event("tout_deselectionner", _params, socket) do
    {:noreply, socket |> assign(:selection, MapSet.new()) |> calculer_tout_coche()}
  end

  def handle_event("supprimer_selection", _params, socket) do
    {ok, refuses} =
      socket.assigns.selection
      |> Enum.map(&Atelier.get_vehicule!/1)
      |> Enum.split_with(&match?({:ok, _}, Atelier.delete_vehicule(&1)))

    socket =
      socket
      |> assign(:selection, MapSet.new())
      |> charger()
      |> flash_suppression(length(ok), refuses)

    {:noreply, socket}
  end

  defp flash_suppression(socket, n, []) when n > 0 do
    put_flash(socket, :info, "#{n} véhicule#{s(n)} supprimé#{s(n)}.")
  end

  defp flash_suppression(socket, n, refuses) do
    plaques = Enum.map_join(refuses, ", ", & &1.immatriculation)
    m = length(refuses)

    socket
    |> then(fn s ->
      if n > 0, do: put_flash(s, :info, "#{n} véhicule#{s(n)} supprimé#{s(n)}."), else: s
    end)
    |> put_flash(
      :error,
      "#{m} véhicule#{s(m)} conservé#{s(m)} (#{plaques}) : un historique d'interventions y est rattaché."
    )
  end

  defp s(n) when n > 1, do: "s"
  defp s(_), do: ""

  defp charger(socket) do
    vehicules =
      [recherche: socket.assigns.recherche]
      |> Atelier.list_vehicules()
      |> filtrer(socket.assigns.filtre)

    socket
    |> assign(:vehicules, vehicules)
    |> assign(:total, Atelier.count_vehicules())
    |> assign(:total_ct, Atelier.count_ct_a_prevoir())
    |> calculer_tout_coche()
  end

  defp filtrer(vehicules, :tous), do: vehicules

  defp filtrer(vehicules, :ct) do
    limite = Date.add(Date.utc_today(), 60)

    Enum.filter(vehicules, fn v ->
      v.date_prochain_ct && Date.compare(v.date_prochain_ct, limite) != :gt
    end)
  end

  defp calculer_tout_coche(socket) do
    vehicules = socket.assigns[:vehicules] || []
    sel = socket.assigns.selection

    assign(
      socket,
      :tout_coche,
      vehicules != [] and Enum.all?(vehicules, &MapSet.member?(sel, &1.id))
    )
  end

  defp kilometrage(nil), do: "—"

  defp kilometrage(km) do
    km
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1\u00A0")
    |> String.reverse()
    |> Kernel.<>("\u00A0km")
  end

  defp libelle_ct(nil), do: "non renseigné"

  defp libelle_ct(date) do
    jours = Date.diff(date, Date.utc_today())
    affichee = Calendar.strftime(date, "%d/%m/%Y")

    cond do
      jours < 0 -> "échu · #{affichee}"
      jours <= 60 -> "dans #{jours} j · #{affichee}"
      true -> affichee
    end
  end

  defp classe_ct(nil), do: "pastille pastille-neutre"

  defp classe_ct(date) do
    jours = Date.diff(date, Date.utc_today())

    cond do
      jours < 0 -> "pastille pastille-danger"
      jours <= 60 -> "pastille pastille-attente"
      true -> "pastille pastille-succes"
    end
  end
end
