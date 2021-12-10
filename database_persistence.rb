require "pg"

class DatabasePersistence
  def initialize(logger)
    @db = PG.connect(dbname: "todos")
    @logger = logger
  end

  def query(sql_statement, *params)
    @logger.info("#{sql_statement}: #{params}")
    @db.exec_params(sql_statement, params)
  end

  def find_list(id)
    sql = "SELECT * FROM list WHERE id = $1;"
    result = query(sql, id)
    
    tuple = result.first
    list_id = tuple["id"].to_i
    todos_array = find_todos_for_list(list_id)

    { id: list_id, name: tuple["name"], todos: todos_array }
  end

  def all_lists
    sql = "SELECT * FROM list;"
    result = query(sql)

    result.map do |tuple|
      list_id = tuple["id"].to_i
      todos = find_todos_for_list(list_id)

      { id: list_id, name: tuple["name"], todos: todos }
    end
  end

  def find_todos_for_list(list_id)
    todo_sql = "SELECT * FROM todo WHERE list_id = $1;"
    todos_result = query(todo_sql, list_id)

    todos = todos_result.map do |todo_tuple|
      { id: todo_tuple["id"].to_i, 
        name: todo_tuple["name"], 
        completed: todo_tuple["completed"] == "t" }
    end
  end

  def create_new_list(list_name)
    # id = next_element_id(@session[:lists])
    # @session[:lists] << { id: id, name: list_name, todos: [] }
  end

  def delete_list(id)
    # @session[:lists].reject! { |list| list[:id] == id }
  end

  def update_list_name(id, new_name)
    # list = find_list(id)
    # list[:name] = new_name
  end

  def create_new_todo(list_id, todo_name)
    # list = find_list(list_id)
    # id = next_element_id(list[:todos])
    # list[:todos] << { id: id, name: todo_name, completed: false }
  end

  def delete_todo_from_list(list_id, todo_id)
    # list = find_list(list_id)
    # list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  def update_todo_status(list_id, todo_id, new_status)
    # list = find_list(list_id)
    # todo = list[:todos].find { |t| t[:id] == todo_id }
    # todo[:completed] = new_status
  end

  def mark_all_todos_as_completed(list_id)
    # list = find_list(list_id)
    # list[:todos].each { |item| item[:completed] = true }
  end
end