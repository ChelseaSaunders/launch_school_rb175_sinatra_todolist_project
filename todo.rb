require "sinatra"

require "sinatra/content_for"
require "tilt/erubis"

require_relative "database_persistence"

configure do 
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

helpers do 
  def list_complete?(list)
    list[:todos_count] > 0 && list[:todos_remaining_count] == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def total_items_count(list)
    list[:todos].size
  end 

  def items_remaining(list)
    list[:todos].count { |item| !item[:completed] }
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_items(list, &block)
    complete, incomplete = list.partition { |item| item[:completed] }


    incomplete.each(&block)
    complete.each(&block)
  end

  def next_todo_id(list_items)
    max = list_items.map { |todo| todo[:id] }.max || 0
    max + 1
  end

end

before do
  @storage = DatabasePersistence.new(logger)
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return error message if the name is invalid. Return nil if the name is valid.
def error_for_list_name(name)
  if !(1..100).cover?(name.length)
    "The list name must be between 1 and 100 characters."
  elsif @storage.all_lists.any? { |list| list[:name] == name }
    "The list name must be unique."
  else
    nil
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Ensures list ID is valid 
def load_list(id)
  list = @storage.find_list(id)
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists" 
end

# View individual lists
get '/lists/:id' do
  id = params[:id].to_i
  @list = load_list(id)
  @list_name = @list[:name]
  @list_id = @list[:id]
  @todos = @list[:todos]
  erb :list, layout: :layout
end

#  Return error message if list item is invalid. Return nil if item is valid.
def error_for_todo(name)
  if !(1..100).cover?(name.length)
    "The list item must be between 1 and 100 characters."
  else
    nil
  end
end

# Add list item
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_new_todo(@list_id, text)

    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Delete todo list item
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:todo_id].to_i

  @storage.delete_todo_from_list(@list_id, todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    # ajax
    status 204 # successful status, no content
  else
    session[:success] = "List item deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Update list item status (complete?)
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  
  todo_id = params[:todo_id].to_i
  is_completed = (params[:completed] == "true")
  
  @storage.update_todo_status(@list_id, todo_id, is_completed)

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all items complete for list
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  
  @storage.mark_all_todos_as_completed(@list_id)

  session[:success] = "All items have been completed."
  redirect "lists/#{@list_id}"
end

# Edit existing list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

# Update existing list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(id, list_name)
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Delete existing list
  post "/lists/:id/delete" do
    id = params[:id].to_i

    @storage.delete_list(id)

    session[:success] = "The list has been deleted."
    if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
      "/lists"
    else
      redirect "/lists"
    end
  end

  after do
    @storage.disconnect
  end