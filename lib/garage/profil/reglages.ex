defmodule Garage.Profil.Reglages do
  @moduledoc """
  Le profil du garagiste, saisi au premier démarrage.

  C'est un *singleton* : il n'existe qu'une seule ligne dans la table.
  La colonne `singleton` vaut toujours 1 et porte un index unique, ce qui
  rend un second profil impossible au niveau de la base.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "reglages" do
    field :nom, :string
    field :prenom, :string
    field :societe, :string
    field :email_pro, :string
    field :date_naissance, :date
    field :anniversaire_vu_le, :date
    field :singleton, :integer, default: 1

    timestamps(type: :utc_datetime)
  end

  # Modifiables à tout moment.
  @champs [:nom, :prenom, :societe, :email_pro]

  # La date de naissance se saisit au premier démarrage et ne bouge plus :
  # elle déclenche la page d'anniversaire, et une date qu'on peut changer
  # n'est pas un anniversaire. Elle n'est donc acceptée que sur une ligne
  # neuve, jamais sur une modification.
  @champs_initiaux [:date_naissance]

  @doc false
  def changeset(reglages, attrs) do
    champs =
      if nouveau?(reglages),
        do: @champs ++ @champs_initiaux,
        else: @champs

    reglages
    |> cast(attrs, champs)
    |> update_change(:nom, &nettoyer/1)
    |> update_change(:prenom, &nettoyer/1)
    |> update_change(:societe, &nettoyer/1)
    |> update_change(:email_pro, &nettoyer_email/1)
    |> validate_required(@champs ++ @champs_initiaux,
      message: "ce champ est obligatoire"
    )
    |> validate_length(:nom, max: 100)
    |> validate_length(:prenom, max: 100)
    |> validate_length(:societe, max: 150)
    |> validate_format(:email_pro, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/,
      message: "adresse e-mail invalide"
    )
    |> validate_date_naissance()
    |> put_change(:singleton, 1)
    |> unique_constraint(:singleton,
      message: "un profil existe déjà"
    )
  end

  @doc """
  Vrai tant que le profil n'a pas été enregistré.
  """
  def nouveau?(%__MODULE__{id: nil}), do: true
  def nouveau?(%__MODULE__{}), do: false

  defp nettoyer(nil), do: nil
  defp nettoyer(v), do: String.trim(v)

  defp nettoyer_email(nil), do: nil
  defp nettoyer_email(v), do: v |> String.trim() |> String.downcase()

  # Une date de naissance dans le futur ou avant 1900 est une faute de
  # frappe, pas une donnée. On la refuse tout de suite.
  defp validate_date_naissance(changeset) do
    validate_change(changeset, :date_naissance, fn :date_naissance, date ->
      cond do
        Date.compare(date, Date.utc_today()) == :gt ->
          [date_naissance: "la date ne peut pas être dans le futur"]

        date.year < 1900 ->
          [date_naissance: "année invalide"]

        true ->
          []
      end
    end)
  end
end
