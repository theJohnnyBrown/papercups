defmodule ChatApi.Repo.Migrations.AddPromptToUserProfiles do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      add(:prompt, :text)
    end
  end
end
