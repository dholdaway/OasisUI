### API Hub for OasisUI ----

# Description: Set of R6 classes for managing connection to API in OasisUI

# library(R6)
# library(oasisui)

### R6 Class for OasisUI API Hub ----

#' OasisAPI
#'
#' @rdname OasisAPI
#'
#' @description R6 Class for OasisUI API Hub.
#'
#' @docType class
#'
#' @return Object of \code{\link{R6Class}} with methods for connecting to Oasis API.
#'
#' @format \code{\link{R6Class}} object.
#'
#' @section Arguments:
#' \describe{
#' \item{user}{string for username.}
#' \item{pwd}{string for user password.}
#' }
#'
#' @section Methods:
#' \describe{
#'
#' Initialize
#'  \item{\code{api_init(host, port)}}{Initialize api and set url private.}
#'  \item{\code{get_url()}}{Return private url.}
#'  \item{\code{get_conn_init()}}{Return conn_init.}
#'  \item{\code{get_http_type()}}{Return http_type.}
#'  api response
#'  \item{\code{api_handle_response(response)}}{Handles api response.}
#'  \item{\code{api_fetch_response(meth, args, logMessage = print)}}{Fetches api response.}
#'  access token
#'  \item{\code{api_post_access_token(user, pwd)}}{Returns response of api access token.}
#'  \item{\code{set_tokens(user, pwd)}}{Set private access token and private refresh token.}
#'  \item{\code{get_access_token()}}{Return private access token.}
#'  refresh token
#'  \item{\code{get_refresh_token()}}{Return private refresh token.}
#'  \item{\code{api_post_refresh_token()}}{Post refresh token.}
#'  version
#'  \item{\code{set_version()}}{Set private version.}
#'  \item{\code{get_version()}}{Return private version.}
#'  healtcheck
#'  \item{\code{api_get_healthcheck()}}{Perform api healthcheck.}
#'  api query
#'  \item{\code{api_basic_query(query_path_basic, query_list, query_method, ...)}}{Construct query without version for the api.}
#'  \item{\code{api_query(query_path, query_list, query_method, ...)}}{Construct query with version for the api.}
#'  \item{\code{api_get_query(query_path, query_list, ...)}}{Construct GET query to the api.}
#'  \item{\code{api_post_query(query_path, query_list, ...)}}{Construct POST query to the api.}
#'  \item{\code{api_delete_query(query_path, query_list, ...)}}{Construct DELETE query to the api.}
#'  \item{\code{api_patch_query(query_path, query_list, ...)}}{Construct PATCH query to the api.}
#'  \item{\code{api_post_file_query(query_path, query_body = NULL, ...)}}{POST file query to the api.}
#'  \item{\code{api_body_query(query_path, query_body = NULL, query_method = "POST", ...)}}{PUT/POST query with body field to the api.}
#'  \item{\code{api_return_query_res(query_path, query_list = NULL, query_method, ...)}}{PUT/POST query with body field to the api.}
#'  return from query
#'  \item{\code{return_df(query_path, api_param = "", query_method = "GET"))}}{MAnipulate data returned from GET query.}
#'  write to disk
#'  \item{\code{api_get_analyses_tar(id, label, dest = tempfile(fileext = ".tar"))}}{GET files and write to disk tar bundle.}
#' }
#'
#' @section Usage:
#' \preformatted{oasisapi <- OasisAPI$new()
#' oasisapi$method(arg)
#' }
#'
#' @importFrom R6 R6Class
#' @importFrom httr GET
#' @importFrom httr POST
#' @importFrom httr DELETE
#' @importFrom httr PUT
#' @importFrom httr PATCH
#' @importFrom httr add_headers
#' @importFrom httr warn_for_status
#' @importFrom httr http_status
#' @importFrom httr status_code
#' @importFrom httr content
#' @importFrom httr upload_file
#' @importFrom httr write_disk
#' @importFrom dplyr bind_rows
#'
#' @export
# OasisAPI ----
OasisAPI <- R6Class(
  "OasisAPI",
  # Private ----
  private = list(
    httptype = NULL, #Type of connection (application/json); default is NULL
    url = NULL, # url to connect with API; default is NULL
    access_token = NULL, # String for API log in; default is NULL
    refresh_token = NULL, # String for API access token refresh; default is NULL
    version = NULL, # Parameter for API connection; default is NULL
    subpath = NULL, # Parameter in case that there is no port
    conn_init = NULL # Structure with the api connection info; default is NULL
  ),
  # Public ----
  public = list(
    # > Initialize ----
    initialize = function(httptype = "application/json", host, port, version, scheme = c("http", "https"), ...) {
      private$httptype <- httptype
      self$api_init(host, port, scheme[1])
      private$version <- version
    },
    get_http_type = function(){
      private$httptype
    },
    api_init = function(host, port, scheme = c("http", "https"), ...) {
      stopifnot(length(host) == 1)
      subpath <- paste(unlist(strsplit(host, "/"))[-1], collapse = "/")
      stopifnot(length(port) == 1)
      url = paste0(scheme[1], "://", host)
      if (port != "") url = paste0(url, ":", port)
      conn_init <- structure(
        list(
          host = host,
          port = port,
          scheme = scheme[1],
          url = url
        ),
        class = c("apisettings")
      )
      private$url <- conn_init$url
      private$subpath <- subpath
      private$conn_init <- conn_init
    },
    # > get conn_init ----
    get_conn_init = function(){
      private$conn_init
    },
    # > get url ----
    get_url = function(){
      private$url
    },
    # > healtcheck ----
    api_get_healthcheck = function(...) {
      tryCatch(
        response <- GET(
          private$url,
          config = add_headers(
            Accept = private$httptype
          ),
          path = paste(private$subpath, "healthcheck/", sep = "/")
        ),
        error = function(e) {
          stop(paste("Health check failed:", e$message))
        }
      )
      if (status_code(response) != 200) {
        stop(paste("Health check failed with:", response$message))
      }
      return(status_code(response))
    },
    # > api response ----
    api_handle_response = function(response) {
      # re-route potential warning for logging
      tryCatch(warn_for_status(response),
               warning = function(w) {warning(w$message)})
      status <- http_status(response)$category
      # 292: more detailed logging of API query issues
      if (status == "Client error" && response$headers[["content-type"]] == "text/html") {
        oasisuiNotification(type = "error",
                            paste0(status_code(response), ": Client error in API query - bad request."))
        warning(paste("Client error", status_code(response), "in api_handle_response, probably trying to access a non-existent query path."))
        logMessage(response$url)
      } else if (status == "Client error" && !is.null(content(response)$detail) && content(response)$detail == "Not found.") {
        oasisuiNotification(type = "error",
                            paste0(status_code(response), ": Client error in API query - not found."))
        warning(paste("Client error", status_code(response), "in api_handle_response, valid query but API did not find / return the requested resource."))
        logMessage(response$url)
      } else if (status == "Server error") {
        oasisuiNotification(type = "error",
                            paste0(status_code(response), ": Server error upon API query - retry and/or check network / API server."))
        warning(paste("Server error", status_code(response), "in api_handle_response."))
      } else if (status_code(response) != 200L) {  # 201 (create ana), 204 (delete pf)
        # oasisuiNotification(type = "message",
        #                     paste0(status_code(response), ": Unexpected status code returned by API query..."))
        logMessage(paste("Unexpected status code", status_code(response), "in api_handle_response."))
      }
      structure(
        list(
          status = status,
          result = response
        ),
        class = c("apiresponse")
      )
    },
    api_fetch_response = function(meth, args, logMessage = print, ...) {
      response <- do.call(meth, eval(args, envir = sys.parent()))
      token_invalid <- status_code(response) == 401L
      # probably expired
      if (token_invalid || status_code(response) == 403L) {
        logMessage("api: refreshing stale OAuth token")
        res <- self$api_post_refresh_token()
        if (res$status == "Success") {
          private$access_token <- content(res$result)$access_token
        } else {
          private$access_token <-  NULL
        }
        response <- do.call(meth, eval(args, envir = sys.parent()))
      }
      response
    },
    # > access token ----
    api_post_access_token = function(user, pwd, ...) {
      response <- POST(
        private$url,
        config = add_headers(
          Accept = private$httptype
        ),
        body = list(username = user, password = pwd),
        encode = "json",
        path = paste(private$subpath, "access_token/", sep = "/")
      )

      self$api_handle_response(response)
    },
    set_tokens = function(user, pwd, ...){
      res <- self$api_post_access_token(user, pwd)
      if (res$status == "Success") {
        res <- content(res$result)
        private$access_token <- res$access_token
        private$refresh_token <- res$refresh_token
      } else {
        private$access_token <- NULL
        private$refresh_token <- NULL
      }
    },
    get_access_token = function(){
      private$access_token
    },
    # > refresh token ----
    get_refresh_token = function(){
      private$refresh_token
    },
    api_post_refresh_token = function(){
      response <- POST(
        self$get_url(),
        config = add_headers(
          Accept = self$get_http_type(),
          Authorization = sprintf("Bearer %s", self$get_refresh_token())
        ),
        encode = "json",
        path = paste(private$subpath, "refresh_token/", sep = "/")
      )

      self$api_handle_response(response)
    },
    # > version ----
    get_version = function(){
      private$version
    },
    # > api query -----
    api_basic_query = function(query_path_basic, query_list = NULL, query_method, ...) {
      request_list <- expression(list(
        private$url,
        config = add_headers(
          Accept = private$httptype,
          Authorization = sprintf("Bearer %s", private$access_token)
        ),
        path = paste(private$subpath, query_path_basic, "", sep = "/"),
        query = query_list
      ))
      response <- self$api_fetch_response(query_method, request_list)
      self$api_handle_response(response)
    },
    api_query = function(query_path, query_list = NULL, query_method, ...) {
      # self$api_basic_query(query_path_basic = paste(private$version, query_path, "", sep = "/"), query_list, query_method)
      request_list <- expression(list(
        private$url,
        config = add_headers(
          Accept = private$httptype,
          Authorization = sprintf("Bearer %s", private$access_token)
        ),
        path = paste(private$subpath, private$version, query_path, "", sep = "/"),
        query = query_list
      ))
      response <- self$api_fetch_response(query_method, request_list)
      self$api_handle_response(response)
    },
    api_get_query = function(query_path, query_list = NULL, ...) {
      self$api_query(query_path, query_list, "GET", ...)
    },
    api_post_query = function(query_path, query_list = NULL, ...) {
      self$api_query(query_path, query_list, "POST", ...)
    },
    api_delete_query = function(query_path, query_list = NULL, ...) {
      self$api_query(query_path, query_list, "DELETE", ...)
    },
    api_patch_query = function(query_path, query_list = NULL, ...) {
      self$api_query(query_path, query_list, "PATCH", ...)
    },
    api_post_file_query = function(query_path,  query_body = NULL,  ...) {
      request_list <- expression(list(
        private$url,
        config = add_headers(
          Accept = private$httptype,
          Authorization = sprintf("Bearer %s", private$access_token)
        ),
        body = list(file = upload_file(query_body)),
        encode = "multipart",
        path = paste(private$subpath, private$version, query_path, "", sep = "/")
      ))
      response <- self$api_fetch_response("POST", request_list)
      self$api_handle_response(response)
    },
    api_body_query = function(query_path,  query_body = NULL, query_method = "POST", ...) {
      request_list <- expression(list(
        private$url,
        config = add_headers(
          Accept = private$httptype,
          Authorization = sprintf("Bearer %s", private$access_token)
        ),
        body = query_body,
        encode = "json",
        path = paste(private$subpath, private$version, query_path, "", sep = "/")
      ))
      response <- self$api_fetch_response(query_method, request_list)
      self$api_handle_response(response)
    },
    api_return_query_res = function(query_path, query_list = NULL, query_method, ...) {
      response <- self$api_query(query_path, query_list = NULL, query_method)
      content(response$result)
    },
    # > return from query ----
    return_df = function(query_path, api_param = "", query_method = "GET") {
      content_lst <- content(self$api_query(query_path, query_list = api_param,  query_method)$result)
      if (length(content_lst) > 0) {
        if (length(content_lst[[1]]) > 1) {
          content_lst <- lapply(content_lst, function(x) {lapply(x, showname)})
        } else {
          content_lst <- list(lapply(content_lst, showname))
        }
        if (length(content_lst) > 1 || length(content_lst[[1]]) > 1) {
          non_null_content_lst <- lapply(content_lst, Filter, f = Negate(is.null))
          non_null_content_lst <- Filter(Negate(is.null), non_null_content_lst)
          for (i in seq_len(length(non_null_content_lst))) {
            if (!is.null(non_null_content_lst[[i]]$groups)) {
              grep_groups <- grep("groups", names(non_null_content_lst[[i]]))
              non_null_content_lst[[i]] <- non_null_content_lst[[i]][- grep_groups]
            }
            if (!is.null(non_null_content_lst[[i]]$analysis_chunks)) {
              grep_chunks <- grep("analysis_chunks", names(non_null_content_lst[[i]]))
              non_null_content_lst[[i]] <- non_null_content_lst[[i]][- grep_chunks]
            }
            if (!is.null(non_null_content_lst[[i]]$sub_task_error_ids)) {
              grep_sub_errors <- grep("sub_task_error_ids", names(non_null_content_lst[[i]]))
              non_null_content_lst[[i]] <- non_null_content_lst[[i]][- grep_sub_errors]
            }
            if (!is.null(non_null_content_lst[[i]]$lookup_chunks)) {
              grep_chunks <- grep("lookup_chunks", names(non_null_content_lst[[i]]))
              non_null_content_lst[[i]] <- non_null_content_lst[[i]][- grep_chunks]
            }
          }
          df <- bind_rows(non_null_content_lst) %>%
            as.data.frame()
        } else if (length(content_lst) == 1 && length(content_lst[[1]]) == 1 && any(grepl("/", content_lst[[1]]))) {
          df <- content_lst[[1]]
        } else {
          df <- NULL
        }
      } else {
        df <- NULL
      }
      df
    },
    # > write to disk ----
    api_get_analyses_tar = function(id, label, dest = tempfile(fileext = ".tar")) {
      request_list <- expression(list(
        private$url,
        config = add_headers(
          Accept = private$httptype,
          Authorization = sprintf("Bearer %s",private$access_token)
        ),
        path = paste(private$subpath, private$version, "analyses", id, label, "", sep = "/"),
        write_disk(dest, overwrite = TRUE)
      ))
      response <- self$api_fetch_response("GET", request_list)
      # response needed to place icon
      self$api_handle_response(response)
    }
  )
)
