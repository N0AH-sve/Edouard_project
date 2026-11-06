defmodule GarageWeb.ClientLive.Show do
  @moduledoc """
  Fiche client : ses coordonnées, ses véhicules, et l'historique
  d'interventions de chacun.
  """
  use GarageWeb, :live_view

  alias Garage.Atelier
  alias Garage.Atelier.Client
  alias Garage.Atelier.Intervention

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      reglages={@reglages}
      titre={Client.nom_complet(@client)}
      actif={:clients}
    >
      <:onglets>
        <Layouts.onglet navigate={~p"/clients"} icone="hero-arrow-left">
          Tous les clients
        </Layouts.onglet>
        <Layouts.onglet navigate={~p"/clients/#{@client}"} icone="hero-user" actif>
          Fiche
        </Layouts.onglet>
      </:onglets>

      <:actions>
        <.link
          navigate={~p"/clients/#{@client}/modifier?retour=fiche"}
          class="inline-flex items-center gap-2 rounded-full border border-base-300 px-5 py-2.5 text-sm font-medium transition hover:border-primary hover:text-primary"
        >
          <.icon name="hero-pencil-square" class="size-4" /> Modifier
        </.link>
        <.link
          navigate={~p"/vehicules/nouveau?client=#{@client.id}"}
          class="inline-flex items-center gap-2 rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-content transition hover:bg-secondary"
        >
          <.icon name="hero-plus" class="size-4" /> Ajouter un véhicule
        </.link>
      </:actions>

      <div class="space-y-6 p-6">
        <%!-- Coordonnées --%>
        <section class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <.fiche_champ libelle="Téléphone" valeur={telephone(@client.telephone)} />
          <.fiche_champ libelle="E-mail" valeur={@client.email} />
          <.fiche_champ libelle="Ville" valeur={ville(@client)} />
          <.fiche_champ libelle="Client depuis" valeur={date_fr(@client.inserted_at)} />
        </section>

        <section :if={@client.adresse not in [nil, ""]}>
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40">Adresse</p>
          <p class="mt-1 whitespace-pre-line text-sm">{@client.adresse}</p>
        </section>

        <section :if={@client.notes not in [nil, ""]} class="rounded-xl bg-base-200 p-4">
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40">
            Notes internes
          </p>
          <p class="mt-1 whitespace-pre-line text-sm">{@client.notes}</p>
        </section>

        <.live_component
          module={GarageWeb.Composants.Documents}
          id="documents-client"
          rattachement={{:client, @client.id}}
        />

        <%!-- Véhicules et historique --%>
        <section class="space-y-4">
          <div class="flex items-center justify-between">
            <h2 class="font-semibold">
              Véhicules
              <span class="ml-1 rounded-full bg-base-200 px-2 py-0.5 text-xs text-base-content/60">
                {length(@client.vehicules)}
              </span>
            </h2>
          </div>

          <p
            :if={@client.vehicules == []}
            class="rounded-xl border border-dashed border-base-300 px-4 py-8 text-center text-sm text-base-content/50"
          >
            Aucun véhicule enregistré pour ce client.
          </p>

          <article
            :for={vehicule <- @client.vehicules}
            class="overflow-hidden rounded-xl border border-base-300"
          >
            <header class="flex flex-wrap items-center gap-3 bg-base-200/60 px-4 py-3">
              <.link
                navigate={~p"/vehicules/#{vehicule}"}
                class="rounded-md bg-neutral px-2.5 py-1 font-mono text-sm font-semibold text-neutral-content"
              >
                {vehicule.immatriculation}
              </.link>
              <span class="text-sm font-medium">
                {[vehicule.marque, vehicule.modele] |> Enum.reject(&is_nil/1) |> Enum.join(" ")}
              </span>
              <span :if={vehicule.annee} class="text-sm text-base-content/50">
                {vehicule.annee}
              </span>
              <span :if={vehicule.kilometrage} class="text-sm tabular-nums text-base-content/50">
                {kilometrage(vehicule.kilometrage)}
              </span>

              <span class={["ml-auto", classe_ct(vehicule.date_prochain_ct)]}>
                CT {date_fr(vehicule.date_prochain_ct)}
              </span>
            </header>

            <div
              :if={Map.get(@historiques, vehicule.id, []) == []}
              class="px-4 py-5 text-center text-sm text-base-content/40"
            >
              Aucune intervention enregistrée.
            </div>

            <table
              :if={Map.get(@historiques, vehicule.id, []) != []}
              class="table-garage w-full text-left"
            >
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Type</th>
                  <th>Description</th>
                  <th class="text-right">Montant</th>
                  <th>Statut</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={i <- Map.get(@historiques, vehicule.id, [])}>
                  <td class="whitespace-nowrap tabular-nums">{date_fr(i.date)}</td>
                  <td class="whitespace-nowrap">{Intervention.libelle_type(i.type)}</td>
                  <td>
                    <.link
                      navigate={~p"/interventions/#{i}"}
                      class="hover:text-primary hover:underline"
                    >
                      {i.description || "—"}
                    </.link>
                  </td>
                  <td class="whitespace-nowrap text-right tabular-nums">
                    {Intervention.formater_euros(i.montant_centimes)}
                  </td>
                  <td>
                    <span class={Intervention.pastille_statut(i.statut)}>
                      {Intervention.libelle_statut(i.statut)}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </article>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :libelle, :string, required: true
  attr :valeur, :string, default: nil

  defp fiche_champ(assigns) do
    ~H"""
    <div class="rounded-xl border border-base-300 px-4 py-3">
      <p class="text-xs font-semibold uppercase tracking-wide text-base-content/40">{@libelle}</p>
      <p class="mt-1 text-sm font-medium">
        {if @valeur in [nil, ""], do: "—", else: @valeur}
      </p>
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    client = Atelier.get_client!(id)

    # L'historique est chargé par véhicule : c'est la lecture naturelle
    # pour un garagiste, qui raisonne par voiture et non par client.
    historiques =
      Map.new(client.vehicules, fn v ->
        {v.id, Atelier.get_vehicule!(v.id).interventions}
      end)

    {:ok,
     socket
     |> assign(:page_title, Client.nom_complet(client))
     |> assign(:client, client)
     |> assign(:historiques, historiques)}
  end

  @impl true
  def handle_info({:message_documents, type, message}, socket) do
    {:noreply, put_flash(socket, type, message)}
  end

  defp ville(%{code_postal: nil, ville: ville}), do: ville
  defp ville(%{code_postal: cp, ville: ville}), do: String.trim("#{cp} #{ville}")

  defp telephone(nil), do: nil

  defp telephone(numero) when is_binary(numero) do
    if String.length(numero) == 10 do
      numero |> String.graphemes() |> Enum.chunk_every(2) |> Enum.map_join(" ", &Enum.join/1)
    else
      numero
    end
  end

  defp kilometrage(km) do
    km
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1\u00A0")
    |> String.reverse()
    |> Kernel.<>("\u00A0km")
  end

  defp date_fr(nil), do: nil
  defp date_fr(%Date{} = d), do: Calendar.strftime(d, "%d/%m/%Y")
  defp date_fr(%DateTime{} = d), do: Calendar.strftime(d, "%d/%m/%Y")

  # Le contrôle technique est l'échéance qui coûte cher si on l'oublie :
  # elle change de couleur à l'approche.
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
