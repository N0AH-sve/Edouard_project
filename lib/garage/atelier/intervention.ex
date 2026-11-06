defmodule Garage.Atelier.Intervention do
  @moduledoc """
  Une intervention sur un véhicule : c'est l'historique du garage.

  Le montant est stocké en centimes entiers. SQLite n'a pas de type
  décimal et les flottants faussent les totaux de facture.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @types [
    revision: "Révision",
    reparation: "Réparation",
    controle_technique: "Contrôle technique",
    pneus: "Pneumatiques",
    carrosserie: "Carrosserie",
    diagnostic: "Diagnostic",
    vidange: "Vidange",
    autre: "Autre"
  ]

  @statuts [
    devis: "Devis",
    en_cours: "En cours",
    termine: "Terminée",
    facture: "Facturée",
    paye: "Payée"
  ]

  schema "interventions" do
    field :date, :date
    field :type, Ecto.Enum, values: Keyword.keys(@types), default: :reparation
    field :kilometrage, :integer
    field :description, :string
    field :pieces, :string
    field :montant_centimes, :integer, default: 0
    field :statut, Ecto.Enum, values: Keyword.keys(@statuts), default: :devis

    # Champ virtuel : le garagiste saisit « 149,90 », pas 14990.
    field :montant_euros, :string, virtual: true

    belongs_to :vehicule, Garage.Atelier.Vehicule
    has_many :documents, Garage.Atelier.Document

    timestamps(type: :utc_datetime)
  end

  @champs [
    :date,
    :type,
    :kilometrage,
    :description,
    :pieces,
    :montant_euros,
    :statut,
    :vehicule_id
  ]

  def types, do: Enum.map(@types, fn {cle, libelle} -> {libelle, cle} end)
  def statuts, do: Enum.map(@statuts, fn {cle, libelle} -> {libelle, cle} end)

  def libelle_type(nil), do: "—"
  def libelle_type(cle), do: Keyword.get(@types, cle, "—")

  def libelle_statut(nil), do: "—"
  def libelle_statut(cle), do: Keyword.get(@statuts, cle, "—")

  @doc "Classe CSS de la pastille de statut (cf. maquette)."
  def pastille_statut(:paye), do: "pastille pastille-succes"
  def pastille_statut(:termine), do: "pastille pastille-succes"
  def pastille_statut(:facture), do: "pastille pastille-info"
  def pastille_statut(:en_cours), do: "pastille pastille-attente"
  def pastille_statut(_), do: "pastille pastille-neutre"

  @doc false
  def changeset(intervention, attrs) do
    intervention
    |> cast(attrs, @champs)
    |> appliquer_montant()
    |> validate_required([:date, :type, :statut, :vehicule_id],
      message: "ce champ est obligatoire"
    )
    |> validate_number(:kilometrage, greater_than_or_equal_to: 0)
    |> validate_number(:montant_centimes, greater_than_or_equal_to: 0)
    |> validate_date_pas_future()
    |> foreign_key_constraint(:vehicule_id)
  end

  # Convertit la saisie en euros vers des centimes entiers. Accepte la
  # virgule comme le point, et les espaces de milliers.
  defp appliquer_montant(changeset) do
    case fetch_change(changeset, :montant_euros) do
      {:ok, nil} ->
        changeset

      {:ok, ""} ->
        put_change(changeset, :montant_centimes, 0)

      {:ok, saisie} ->
        case parser_euros(saisie) do
          {:ok, centimes} -> put_change(changeset, :montant_centimes, centimes)
          :error -> add_error(changeset, :montant_euros, "montant invalide")
        end

      :error ->
        changeset
    end
  end

  @doc """
  « 1 234,56 » → 123456 centimes.
  """
  def parser_euros(saisie) when is_binary(saisie) do
    nettoye =
      saisie
      |> String.replace(~r/[\s\x{00A0}€]/u, "")
      |> String.replace(",", ".")

    case Float.parse(nettoye) do
      {valeur, ""} when valeur >= 0 -> {:ok, round(valeur * 100)}
      _ -> :error
    end
  end

  @doc """
  123456 centimes → « 1 234,56 € ».
  """
  def formater_euros(nil), do: "—"

  def formater_euros(centimes) when is_integer(centimes) do
    euros = div(centimes, 100)
    cents = rem(abs(centimes), 100)

    entier =
      euros
      |> Integer.to_string()
      |> String.reverse()
      |> String.replace(~r/(\d{3})(?=\d)/, "\\1\u00A0")
      |> String.reverse()

    "#{entier},#{String.pad_leading(Integer.to_string(cents), 2, "0")}\u00A0€"
  end

  defp validate_date_pas_future(changeset) do
    validate_change(changeset, :date, fn :date, date ->
      if Date.compare(date, Date.utc_today()) == :gt,
        do: [date: "une intervention ne peut pas être datée dans le futur"],
        else: []
    end)
  end
end
