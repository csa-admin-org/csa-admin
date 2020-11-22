module SharedDataPreview
  extend ActiveSupport::Concern

  private

  def random
    @random ||= Random.new(params[:random] || rand)
  end

  def member
    OpenStruct.new(
      id: 1,
      name: ['Jane Doe', 'John Doe'].sample(random: random),
      language: params[:locale] || I18n.locale)
  end
end
