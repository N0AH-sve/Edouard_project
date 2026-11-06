defmodule Garage.Fichiers do
  @moduledoc "Contenus de fichiers pour les tests."

  @doc "Un PDF minimal mais valide (en-tête, objets, table xref)."
  def pdf(texte \\ "Facture") do
    """
    %PDF-1.4
    1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
    2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
    3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj
    trailer<</Root 1 0 R>>
    % #{texte}
    %%EOF
    """
  end

  @doc "Un fichier qui se fait passer pour un PDF sans en être un."
  def faux_pdf, do: "Je ne suis pas un PDF, juste du texte."
end
