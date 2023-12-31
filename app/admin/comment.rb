ActiveAdmin.register ActiveAdmin::Comment, as: "Comment" do
  controller do
    def destroy
      resource.destroy
      redirect_to resource.resource
    end
  end
end
