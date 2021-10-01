require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

configure do 
  enable :sessions
  set :session_secret, 'secret'
end

helpers do 
  def list_complete?(list)
    total_items_count(list) > 0 && items_remaining(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def total_items_count(list)
    list[:todos].size
  end 

  def items_remaining(list)
    list[:todos].count { |item| item[:completed] == false }
  end

  def display_list(list, index)
    "<li class='#{list_class(list)}'>
      <a href='/lists/#{index}'>
        <h2>#{list[:name]}</h2>
        <p>#{items_remaining(list)}/#{total_items_count(list)}</p>
      </a>
    </li>"
  end

  def organize_list_display(lists)
    lists.each_with_index do |list, index|
      display_list(list, index) if !list_complete?(list)
    end
    
    lists.each_with_index do |list, index|
      display_list(list, index) if list_complete?(list)
    end
  end

  def display_list_items(item, item_id)
    li_class_type = item[:completed] ? "<li class='complete'>" : "<li>"

    "#{li_class_type}
      <form action='/lists/#{@list_id}/todos/#{item_id}>' method='post' class='check'>
        <input type='hidden' name='completed' value='#{!item[:completed]}' />
        <button type='submit'>Complete</button>
      </form>
      <h3>#{item[:name]}</h3>
      <form action='/lists/#{@list_id}/todos/#{item_id}/delete' method='post' class='delete'>
        <button type='submit'>Delete</button>
      </form>
    </li>" 
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
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
  elsif session[:lists].any? { |list| list[:name] == name }
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
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View individual lists
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
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
  @list = session[:lists][@list_id]
  text = params[:todo].strip
  error = error_for_todo(text)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: text, completed: false }
    session[:success] = "List item added."
    redirect "lists/#{@list_id}"
  end
end

# Delete todo list item
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:todo_id].to_i
  @list[:todos].delete_at(todo_id)
  session[:success] = "List item deleted."

  redirect "lists/#{@list_id}"
end

# Update list item status (complete?)
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i

  is_completed = params[:completed] == "true"

  @list[:todos][todo_id][:completed] = is_completed
  session[:success] = "List item updated."
  redirect "lists/#{@list_id}"
end

# Mark all items complete for list
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  
  @list[:todos].each { |item| item[:completed] = true }

  session[:success] = "All items have been completed."
  redirect "lists/#{@list_id}"
end

# Edit existing list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = session[:lists][id]
  erb :edit_list, layout: :layout
end

# Update existing list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = session[:lists][id]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Delete existing list
post "/lists/:id/delete" do
  id = params[:id].to_i
  session[:lists].delete_at(id)

  session[:success] = "The list has been deleted."
  redirect "/lists"
end