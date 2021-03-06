require "pg"

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
      PG.connect(ENV['DATABASE_URL'])
    else
      PG.connect(dbname: "todos")
    end
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
    sql = <<~SQL
      SELECT list.*, 
        COUNT(todo.id) AS todos_count,
        COUNT(NULLIF(todo.completed, true)) AS todos_remaining_count
        FROM list 
        LEFT JOIN todo ON todo.list_id = list.id
        GROUP BY list.id
        ORDER BY list.name;
    SQL

    result = query(sql)

    result.map do |tuple|
      { id: tuple["id"].to_i, 
        name: tuple["name"], 
        todos_count: tuple["todos_count"].to_i,
        todos_remaining_count: tuple["todos_remaining_count"].to_i }
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
    sql = "INSERT INTO list (name) VALUES ($1);"
    query(sql, list_name)
  end

  def delete_list(id)
    sql = "DELETE FROM list WHERE id = $1;"
    query(sql, id)
  end

  def update_list_name(id, new_name)
    sql = "UPDATE list SET name = $1 WHERE id = $2;"
    query(sql, new_name, id)
  end

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todo (name, list_id) VALUES ($1, $2);"
    query(sql, todo_name, list_id)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = "DELETE FROM todo WHERE id = $1 AND list_id = $2"
    query(sql, todo_id, list_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todo SET completed = $1 WHERE id = $2 AND list_id = $3"
    query(sql, new_status, todo_id, list_id)
  end

  def mark_all_todos_as_completed(list_id)
    sql = "UPDATE todo SET completed = true WHERE list_id = $1;"
    query(sql, list_id)
  end

  def disconnect
    @db.close
  end
end