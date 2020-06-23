# -*- coding: utf-8 -*-
class TimeLoggingAppController < ApplicationController
  # this implements a specialised read only redmine http interface for the time logging app that is substantially faster than the redmine rest-api.
  # tips
  #   logging:
  #     logger.info argument ...
  #     logger.info issue.to_json
  #   database queries: http://guides.rubyonrails.org/active_record_querying.html

  unloadable

  if Rails::VERSION::MAJOR >= 4
    before_action :check_auth
  else
    before_filter :check_auth
  end

  public

  def time_entry
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
    entries_count = 10
    # issues or projects with time entries recently created by the user
    t = "select t.issue_id, t.project_id, t.updated_on from time_entries t where t.user_id = #{User.current.id}"
    # issues with journal entries recently created by the user
    j = "select i.id issue_id, i.project_id, j.created_on updated_on from journals j, issues i where j.journalized_type = 'Issue' and j.user_id = #{User.current.id} and j.journalized_id = i.id"
    # assigned issues
    i = "select i.id issue_id, i.project_id, i.updated_on from issues i where i.assigned_to_id = #{User.current.id}"
    # union and limit
    t = "select distinct issue_id, project_id from (#{t} union #{j} union #{i} order by updated_on desc) a limit #{entries_count}"
    # add parent projects and rename fields
    t = "select t.*,i.subject issue_subject,p.name project_name,p2.id project_parent_id,p2.name project_parent_name,v.name version_name,#{issue_is_closed_sql('i')},i.updated_on from (#{t}) t inner join projects p" +
      " left outer join projects p2 on p2.id=p.parent_id left outer join issues i on i.id=t.issue_id left outer join versions v on v.id=i.fixed_version_id where p.id=t.project_id"
    render :json => TimeEntry.connection.select_all(t)
  end

  def overview
    # lists all time_entries of the last x days and marks those with unusual hours.
    @display_columns = [:spent_on, :hours, :project]
    # get column labels
    @display_column_headings = @display_columns.map {|a| translate(("field_" + a.to_s).to_sym) }
    # load time entries grouped by day
    sql_select = "select spent_on, sum(hours) hours_day, group_concat(project_id) project_ids"
    sql_where = "where user_id=#{User.current.id} and tyear=#{DateTime.now.year}"
    sql = "#{sql_select} from time_entries #{sql_where} group by spent_on order by spent_on asc"
    time_entries = TimeEntry.connection.select_all(sql).to_a
    # return early if empty
    if time_entries.empty?
      @time_entries = []
      render :layout => "base"
      return
    end
    if time_entries.first["spent_on"].is_a? String
      # dealing with database without a date type
      time_entries.each {|a| a["spent_on"] = Date.strptime(a["spent_on"], "%Y-%m-%d")}
    end
    # get the most common hour value
    hours = time_entries.map {|a| a["hours_day"]}
    hours_and_count = hours.map {|a| [a, hours.count(a)]}.sort{|a, b| b[1] <=> a[1]}
    most_common_hours = hours_and_count.first[0]
    # start with earliest date and create entries for each day
    previous_date = time_entries.first["spent_on"]
    time_entries = time_entries.reduce([]) {|result, a|
      # add null entries between previous and current date
      range = previous_date..(a["spent_on"] - 1)
      null_entries = range.map {|b|
        next if b.saturday? or b.sunday?
        { :spent_on => I18n.l(b), :spent_on_date => b,
          :project => "", :issue => "", :hours => "", :less_hours => true }
      }.compact
      projects = a["project_ids"].split(",").uniq.map{|id| id.to_i }
      projects = Project.find(projects).map{|a| a[:name]}
      current = {
        :spent_on => I18n.l(a["spent_on"]),
        :spent_on_date => a["spent_on"],
        :hours => decimal_hours_to_hours_minutes(a["hours_day"].round(2)),
        :project => projects.join(", ")
      }
      current[:less_hours] = (most_common_hours - a["hours_day"]).abs > 0.1
      previous_date = a["spent_on"] + 1
      result + null_entries + [current]
    }
    @time_entries = time_entries.reverse
    render :layout => "base"
  end

  def time_entries spent_on=params[:spent_on]
    spent_on = spent_on ? Date.strptime(spent_on) : Date.today
    time_entries = TimeEntry
                   .includes(:issue, :project)
                   .joins("left outer join projects on time_entries.project_id=projects.id")
      .select("projects.name,time_entries.id,time_entries.spent_on,time_entries.hours" +
              ",time_entries.project_id,time_entries.issue_id,time_entries.activity_id,time_entries.comments")
      .order("time_entries.created_on desc")
      .where("spent_on" => spent_on, "user_id" => User.current)
    # the time_entries returned are model objects. In the following we convert them
    # to simpler hashes and create the desired structure.
    time_entries = time_entries.map {|e|
      result = pick(e, "id", "spent_on", "hours", "comments")
      result["activity"] = {"id" => e["activity_id"]}
      result["project"] = {"id" => e["project_id"], "name" => e.project["name"]}
      if e["issue_id"]
        result["issue"] = {"id" => e["issue_id"], "subject" => e.issue["subject"],
          "spent_hours" => TimeEntry.select("sum(hours) as spent_hours").where("issue_id" => e.issue_id).first["spent_hours"],
          "estimated_hours" => e.issue["estimated_hours"]}
      else
        result["project"]["spent_hours"] = TimeEntry.select("sum(hours) as spent_hours")
          .where("project_id" => e["project_id"], "user_id" => User.current).first["spent_hours"]
      end
      result
    }
    render :json => {"time_entries" => time_entries}
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
    # return the current, total spent time for a project or issue.
    return unless project_id or issue_id
    if issue_id
      entry = TimeEntry.select("sum(time_entries.hours) hours")
                .where("issue_id = ?", issue_id)
                .group("time_entries.issue_id")
                .take
    elsif project_id
      entry = TimeEntry.select("sum(time_entries.hours) hours")
                .where("project_id = ?", project_id)
                .group("time_entries.project_id")
                .take
    end
    render :json => {"total" => entry ? entry["hours"] : 0}
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

  def get_backend_urls
    urls = {}
    actions = ["projects_and_issues", "recent", "spent_time", "time_entries"]
    actions.each {|action|
      urls[action] = url_for({controller: "time_logging_app", action: action})
    }
    urls["overview"] = url_for({controller: "time_logging_app", action: "overview", html_options: {target: "_blank", class: "overview"}})
    urls["time_entries_redmine"] = url_for({controller: "timelog"})
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
    # creates an object that is passed to the frontend javascript.
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
    {"activities" => activities,
     "backend_urls" => get_backend_urls,
     # Token for "protect_from_forgery" csrf protection.
     # It is rendered into the page and used by the javascript in every request.
     # It is not entirely sure if form_authenticity_token is the correct token but it works.
     "csrf_token" => form_authenticity_token.to_s,
     "datepicker" => datepicker,
     "only_issues" => "1" == Setting.plugin_redmine_time_logging_app["only_issues"],
     "overbooking_warning" => "1" == Setting.plugin_redmine_time_logging_app["overbooking_warning"],
     "issues_closed_past_days" => Setting.plugin_redmine_time_logging_app["issues_closed_past_days"],
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
    # convert a decimal hours number into a hh[:mm] string represultentation
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
                                             project_permission_condition(User.current, :log_time))
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
        select.where("status_id" => @issue_status_open, "project_id" => project_ids)
      elsif "closed" == status
        select.where("status_id" => @issue_status_closed, "project_id" => project_ids)
      else
        time_now = DateTime.now
        select.where(
                   "(issues.status_id in(?) or (issues.status_id in(?) and issues.updated_on between ? and ?))" +
                     " and issues.project_id in(?)",
                   @issue_status_open, @issue_status_closed, time_now - past_days, time_now, project_ids)
      end
    else
      if "open" == status
        select.where("status_id" => @issue_status_open)
      elsif "closed" == status
        select.where("status_id" => @issue_status_closed)
      else
        time_now = DateTime.now
        select.where(
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
