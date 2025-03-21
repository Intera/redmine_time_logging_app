# -*- coding: utf-8 -*-
class TimeLoggingAppController < ApplicationController
  # this implements a specialised read only redmine http interface for the time logging app that is substantially faster than the redmine rest-api.
  # tips
  #   logging:
  #     logger.info argument ...
  #     logger.info issue.to_json
  #   database queries: http://guides.rubyonrails.org/active_record_querying.html

  if Rails::VERSION::MAJOR >= 4
    before_action :check_auth
  else
    before_filter :check_auth
  end

  public

  def index
    redmine_data = get_redmine_data
    @javascript_tag_content = "var redmineData = " + ActiveSupport::JSON.encode(redmine_data)
    render layout: false
  end

  def recent
    load_issue_stati()
    if @issue_status_closed.empty? or @issue_status_open.empty?
      render :json => []
      return
    end
    user_id = User.current.id
    past_date = (DateTime.now - 180).to_i
    if "SQLite" == ActiveRecord::Base.connection.adapter_name
      past_date_sql = "datetime(#{past_date}, 'unixepoch')"
    else
      past_date_sql = "from_unixtime(#{past_date})"
    end
    # recently logged-to issues
    t1 = "select issue_id from time_entries where issue_id is not null and user_id = #{user_id} and updated_on > #{past_date}"
    t = "select distinct id issue_id, project_id, updated_on from issues where id in (#{t1}) order by updated_on desc limit 2"
    # assigned issues
    i = "select id issue_id, project_id, updated_on from issues where assigned_to_id = #{user_id} order by updated_on desc limit 6"
    # recently assigned-away from issues
    columns = "distinct i.id issue_id, i.project_id, i.updated_on"
    tables = "issues i, journals j, journal_details jd"
    where = "i.id = j.journalized_id and jd.journal_id = j.id and prop_key='assigned_to_id' and jd.old_value = #{user_id}"
    j = "select #{columns} from #{tables} where #{where} order by i.updated_on desc limit 2"
    # union
    u = "select distinct issue_id, project_id, updated_on from (select * from (#{i}) i union select * from (#{t}) t union select * from (#{j}) j) a"
    # add data from related tables
    columns = "t.issue_id, t.project_id, t.updated_on, i.subject issue_subject, i.updated_on," +
      " p.name project_name, p2.id project_parent_id, p2.name project_parent_name, v.name version_name, #{issue_is_closed_sql('i')}"
    tables = "(#{u}) t inner join projects p on p.id = t.project_id" +
      " left outer join projects p2 on p2.id = p.parent_id left outer join issues i on i.id = t.issue_id" +
      " left outer join versions v on v.id = i.fixed_version_id"
    r = "select distinct #{columns} from #{tables}"
    render :json => TimeEntry.connection.select_all(r)
  end

  def overview
    @redmine_data = {
      "time_logging_app_url" => url_for({controller: "time_logging_app", action: "index"})
    }
    year = DateTime.now.year
    @data = {
      :per_day => overview_rows(:day, year),
      :per_week => overview_rows(:week, year),
      :per_year => overview_rows(:year, year)
    }
    render :layout => "base"
  end

  def time_entries_list spent_on
    spent_on = spent_on ? Date.strptime(spent_on) : Date.today
    time_entries = TimeEntry
                   .includes(:issue, :project)
                   .joins("left outer join projects on time_entries.project_id=projects.id")
      .select("projects.name, time_entries.id, time_entries.spent_on, time_entries.hours, " +
              "time_entries.project_id, time_entries.issue_id, time_entries.activity_id, time_entries.comments")
      .order("time_entries.created_on desc")
      .where("spent_on" => spent_on, "user_id" => User.current)
    time_entries = time_entries.map {|a|
      result = pick(a, "id", "spent_on", "hours", "comments")
      result["activity"] = {"id" => a["activity_id"]}
      result["project"] = {"id" => a["project_id"], "name" => a.project["name"]}
      if a["issue_id"]
        result["issue"] = {"id" => a["issue_id"], "subject" => a.issue["subject"],
          "spent_hours" => TimeEntry.where("issue_id" => a.issue_id).sum("hours"),
          "estimated_hours" => a.issue["estimated_hours"]}
      else
        result["project"]["spent_hours"] = TimeEntry.where("project_id" => e["project_id"], "user_id" => User.current).sum("hours")
      end
      result
    }
    render :json => {"time_entries" => time_entries}
  end

  def time_entries
    if request.get?
      time_entries_list params[:spent_on]
    elsif request.post? or request.put?
      spent_on = Date.strptime(params["spent_on"], "%Y-%m-%d")
      data = {
          :user_id => User.current.id,
          :activity_id => params["activity_id"].to_i,
          :comments => params["comments"],
          :hours => params["hours"].to_f,
          :project_id => params["project_id"].to_i,
          :spent_on => spent_on
      }
      if params["issue_id"]
        data[:issue_id] = params["issue_id"].to_i
      end
      if request.post?
        TimeEntry.new(data).save!
      else
        a = TimeEntry.find(params["id"])
        return unless User.current.id == a.user_id
        a.update!(data)
      end
    elsif request.delete?
      a = TimeEntry.find(params["id"])
      return unless User.current.id == a.user_id
      a.delete
    end
  end

  def projects_and_issues
    load_issue_stati()
    if @issue_status_closed.empty? or @issue_status_open.empty?
      render :json => {"issues" => [], "projects" => []}
      return
    end
    projects = get_projects
    past_days = params[:closed_past_days] ? params[:closed_past_days].to_i : 7
    issues = get_issues params[:status], projects.map{|b| b["id"]}, past_days
    issues = issues.map {|b|
      {
        "estimated_hours" => b["estimated_hours"],
        "id" => b["id"],
        "is_closed" => b["issue_is_closed"] == 1,
        "project" => {"id" => b.project_id },
        "subject" => b.subject,
        "version" => b.version_name
      }
    }
    render :json => {"issues" => issues, "projects" => projects}
  end

  def spent_time project_id=params["project_id"], issue_id=params["issue_id"]
    # return the current total spent time for a project or issue.
    unless issue_id or project_id
      render :json => {"total" => 0}
      return
    end
    if issue_id
      sql_condition = "issue_id = #{issue_id.to_i}"
      sql_group = "issue_id"
    elsif project_id
      sql_condition = "project_id = #{project_id.to_i}"
      sql_group = "project_id"
    end
    sql = "select sum(hours) hours from #{TimeEntry.table_name} where #{sql_condition} group by #{sql_group}"
    entry = TimeEntry.connection.select_all(sql)
    hours = 1 == entry.length ? entry.first["hours"].to_f : 0
    render :json => {"total" => hours}
  end

  def estimate_check
    # experimental view to compare estimates with actual spent time for closed tickets
    access_allowed = User.current.allowed_to?(:log_time, nil, :global => true) ||
                       User.current.allowed_to?(:edit_own_time_entries, nil, :global => true) ||
                       User.current.admin?
    if access_allowed
      estimates = get_estimates params[:project]
      @estimates = estimates ? estimates : []
      @column_titles = %w(ticket-id subject estimated spent difference)
    end
  end

  private

  def overview_rows_get_projects project_id_to_name, project_ids, type, time_column, time_sql
    return "" if project_ids.empty?
    ids_sql = project_ids.join ","
    where_sql = "where user_id=#{User.current.id} and project_id in(#{ids_sql}) and #{time_column}=#{time_sql}"
    sql = "select project_id, sum(hours) hours_sum from time_entries #{where_sql} group by project_id order by hours_sum desc"
    time_entries = TimeEntry.connection.select_all(sql).to_a
    total_hours = time_entries.reduce(0) {|sum, a| sum + a["hours_sum"]}
    time_entries = time_entries.map {|a|
      percentage = (100 * a["hours_sum"] / total_hours).floor
      name = project_id_to_name[a["project_id"]]
      if percentage < 1 then name
      else "#{name} (#{percentage}%)" end
    }
    time_entries.join ", "
  end

  def overview_rows_get_project_id_to_name
    id_and_name = TimeEntry.connection.select_all("select id, name from projects").to_a
    id_and_name.reduce({}) {|result, a|
      result[a["id"]] = a["name"]
      result
    }
  end

  def overview_rows type, year
    group_column_by_type = {:year => "tyear", :week => "tweek", :day => "spent_on"}
    group_column = group_column_by_type[type]
    if :year == type
      year_sql = ((year - 5)..year).to_a.join ","
      year_sql = "tyear in (#{year_sql})"
    else year_sql = "tyear=#{year}" end
    select_sql = "select #{group_column}, sum(hours) hours_sum, group_concat(project_id) project_ids"
    where_sql = "where user_id=#{User.current.id} and #{year_sql}"
    sql = "#{select_sql} from time_entries #{where_sql} group by #{group_column} order by #{group_column} desc"
    time_entries = TimeEntry.connection.select_all(sql).to_a
    time_entries.each {|a|
      a["project_ids"] = a["project_ids"].split(",").uniq.map{|id| id.to_i}
    }
    project_id_to_name = overview_rows_get_project_id_to_name
    total = time_entries.pluck("hours_sum").sum
    average_count = [1, time_entries.size].max
    average = total / average_count
    time_entries = time_entries.map {|a|
      if "spent_on" == group_column
        timestamp = a[group_column].to_time.to_i
        if "SQLite" == ActiveRecord::Base.connection.adapter_name
          group_value_sql = "datetime(#{timestamp}, 'unixepoch')"
        else
          group_value_sql = "from_unixtime(#{timestamp})"
        end
      else
        group_value_sql = a[group_column]
      end
      projects = overview_rows_get_projects project_id_to_name, a["project_ids"], type, group_column, group_value_sql
      highlight_hours = 0.5 <= (average - a["hours_sum"])
      date_format = "%Y-%m-%d"
      formatted_group_column = a[group_column]
      if :year == type
        spent_on_date = Date.new(a[group_column]).strftime(date_format)
      elsif :week == type
        spent_on_date = Date.commercial(year, a[group_column], 1).strftime(date_format)
      elsif :day == type
        date = a[group_column]
        spent_on_date = date
        day_name = t("date.abbr_day_names")[date.wday % 7]
        formatted_group_column = date.strftime "%Y-%m-%d, #{day_name}"
      else
        spent_on_date = a[group_column]
        formatted_group_column = a[group_column]
      end
      {
        group_column => formatted_group_column,
        :hours => decimal_hours_to_hours_minutes(a["hours_sum"].round(2)),
        :spent_on_date => spent_on_date,
        :project => projects,
        :highlight_hours => highlight_hours
      }
    }
    columns = [group_column, :hours, :project]
    headings = columns.map{|a| translate("field_#{a}".to_sym)}
    average_hours = decimal_hours_to_hours_minutes average.round(2)
    if :year == type
      total_hours = decimal_hours_to_hours_minutes total.round(2)
      headings[1] += " (⌀ #{average_hours}, ∑ #{total_hours})"
    else
      headings[1] += " (⌀ #{average_hours})"
    end
    {:columns => columns, :headings => headings, :rows => time_entries}
  end

  def get_backend_urls
    urls = {}
    actions = ["projects_and_issues", "recent", "spent_time", "time_entries"]
    actions.each {|action|
      urls[action] = url_for({controller: "time_logging_app", action: action})
    }
    urls["issues_redmine"] = url_for({controller: "issues"})
    urls["projects_redmine"] = url_for({controller: "projects"})
    urls
  end

  def get_comma_translation key
    b = translate key
    b and b.split ","
  end

  def get_translations
    # get translations needed in the frontend. I18n.translate(".") didnt support fallback languages.
    # prefer redmine core translations because they are available in many languages.
    keys = [
      # redmine core
      :button_create,
      :button_delete,
      :button_edit,
      :button_update,
      :field_activity,
      :field_hours,
      :general_text_no,
      :general_text_yes,
      :label_comment,
      :label_date,
      :text_time_entries_destroy_confirmation,
      # plugin
      :button_duplicate,
      :confirm_delete,
      :error_404_not_found,
      :field_minutes,
      :general_text_or,
      :issue_or_project,
      :no_time_entries_loaded,
      :overbooking_warning,
      :overview_title,
      :redmine_message,
      :unavailable_project
    ]
    keys.inject({}) {|result, a| result[a] = translate(a); result}
  end

  def get_redmine_data
    # creates an object that is passed to the frontend javascript
    current_user = User.current
    activities = TimeEntryActivity.select("id, name, project_id, parent_id, active").map{|b|
      {"id" => b["id"], "name" => b["name"], "project_id" => b["project_id"],
       "parent_id" => b["parent_id"], "active" => b["active"]}}
    datepicker = {
      "month_names" => get_comma_translation("datepicker_month_names"),
      "month_names_short" => get_comma_translation("datepicker_month_names_short"),
      "day_names" => get_comma_translation("datepicker_day_names"),
      "day_names_min" => get_comma_translation("datepicker_day_names_min"),
      "day_names_short" => get_comma_translation("datepicker_day_names_short"),
      "today" => translate("datepicker_today"),
      "close" => translate("datepicker_close"),
      "next" => translate("datepicker_next"),
      "prev" => translate("datepicker_prev")
    }
    datepicker_setting_names = ["date_format", "max_date", "min_date", "first_day"]
    datepicker_setting_names.each {|a|
      datepicker[a] = Setting.plugin_redmine_time_logging_app["datepicker_#{a}"]
    }
    issues_closed_past_days = Setting.plugin_redmine_time_logging_app["issues_closed_past_days"].to_i
    spent_on = params[:spent_on]
    if spent_on
      spent_on_date = Date.parse spent_on
      past_days = (Date.today - spent_on_date).to_i
      issues_closed_past_days = [past_days, issues_closed_past_days].max
      datepicker["min_date"] = "-#{issues_closed_past_days}d"
    end
    {"activities" => activities,
     "backend_urls" => get_backend_urls,
     "spent_on" => spent_on,
     # Token for "protect_from_forgery" csrf protection.
     # It is rendered into the page and used by the javascript in every request.
     # It is not entirely sure if form_authenticity_token is the ideal token but it works.
     "csrf_token" => form_authenticity_token.to_s,
     "datepicker" => datepicker,
     "only_issues" => "1" == Setting.plugin_redmine_time_logging_app["only_issues"],
     "overbooking_warning" => "1" == Setting.plugin_redmine_time_logging_app["overbooking_warning"],
     "issues_closed_past_days" => issues_closed_past_days,
     # currently includes all redmine core translations until a better way is found
     "redmine_version_major" => Redmine::VERSION::MAJOR,
     "redmine_version_minor" => Redmine::VERSION::MINOR,
     "translations" => get_translations(),
     "user" => {"id" => current_user["id"], "language" => current_user["language"]}}
  end

  def load_issue_stati
    if not @issue_status_open
      @issue_status_open = IssueStatus.select("id").where("is_closed=?", false).pluck :id
      @issue_status_closed = IssueStatus.where("is_closed=?", true).pluck :id
    end
  end

  def check_auth
    allowed = (User.current.allowed_to?(:log_time, nil, :global => true) ||
               User.current.allowed_to?(:edit_own_time_entries, nil, :global => true) ||
               User.current.admin?)
    redirect_to signin_url unless allowed
  end

  def issue_is_closed_sql table
    load_issue_stati()
    "case when #{table}.status_id in(#{@issue_status_closed.join(',')}) then 1 else 0 end issue_is_closed"
  end

  def decimal_hours_to_hours_minutes n
    # convert a decimal hours number into a hh[:mm] string
    minutes = ((n % 1) * 60).round(0)
    hours = n.floor
    r = hours.to_s
    if minutes > 0
      minutes = "%02d" % minutes.to_s
      "#{r}:#{minutes}"
    else r end
  end

  def pick hash, *keys
    result = {}
    keys.each {|key| result[key] = hash[key] }
    result
  end

  def projects_add_properties projects
    projects.each {|a|
      if a["parent_id"]
        a["parent_name"] =
          Project.connection.select_all("select name from projects where id=" +
                                        a["parent_id"].to_s + " limit 1")[0]["name"]
      end
    }
    projects
  end

  def get_projects
    projects = Project.connection.select_all("select parent_id,id,name from projects where " +
                                             project_permission_condition(User.current, :log_time) + " order by projects.id desc")
    projects_add_properties projects
    projects
  end

  def get_issues status=false, project_ids=false, past_days=7
    select = Issue
      .joins("left outer join versions on versions.id = issues.fixed_version_id")
      .select("issues.id, issues.project_id, issues.subject, issues.estimated_hours, versions.name as version_name, #{issue_is_closed_sql('issues')}")
    # multiple .where() just did not work
    if project_ids
      if "open" == status
        select.order("issues.id desc").where("status_id" => @issue_status_open, "project_id" => project_ids)
      elsif "closed" == status
        select.order("issues.id desc").where("status_id" => @issue_status_closed, "project_id" => project_ids)
      else
        time_now = DateTime.now
        select.order("issues.id desc").where(
                   "(issues.status_id in(?) or (issues.status_id in(?) and issues.updated_on between ? and ?))" +
                     " and issues.project_id in(?)",
                   @issue_status_open, @issue_status_closed, time_now - past_days, time_now, project_ids)
      end
    else
      if "open" == status
        select.order("issues.id desc").where("status_id" => @issue_status_open)
      elsif "closed" == status
        select.order("issues.id desc").where("status_id" => @issue_status_closed)
      else
        time_now = DateTime.now
        select.order("issues.id desc").where(
                   "(issues.status_id in(?) or (issues.status_id in(?) and issues.updated_on between ? and ?))",
                   @issue_status_open, @issue_status_closed, time_now - past_days, time_now)
      end
    end
  end

  def project_permission_condition user, permission, options={}
    Project.allowed_to_condition(user, permission, options)
  end

  def assoc_select obj, keys
    keys.map do |key| obj[key] end
  end

  def get_estimates project_id
    project_id = project_id ? " and id=#{project_id.to_i}" : ""
    visible_projects = Project.connection.select_all("select id from projects where " +
                                                     project_permission_condition(User.current, :log_time) + project_id)
    visible_projects = visible_projects.map{|e| e["id"] }
    issues = Issue
      .select("id,estimated_hours,subject,status_id")
      .order("id")
      .where("project_id" => visible_projects)
      .includes(:time_entries)
    result = []
    issues.each {|iss|
      next if (not iss.estimated_hours)
      hours = iss.time_entries.reduce(0) {|r, e| r += e.hours }
      next if (1 > hours) or (hours - iss.estimated_hours == 0)
      result.push [iss.id, iss.subject, iss.estimated_hours, hours, (hours - iss.estimated_hours)]
    }
    result = result.sort {|a, b|
      b.last <=> a.last
    }
    result
  end
end
