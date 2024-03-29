batch_encode_post <- function(df, batch_size = 10, parallel = FALSE, typecast = FALSE){
  
  records <- df %>%
    dplyr::mutate(rowid = row_number()) %>%
    dplyr::group_by(.data$rowid) %>%
    dplyr::group_split(.keep = FALSE)
  
  records_lst <- lapply(records, as.list)
  
  batches <- split_list(records_lst, batch_size)
  
  
  if (parallel){
    message("JSON encoding data for POST")
    
    cl <- parallel::makeCluster(parallel::detectCores(), type = 'SOCK')
    
    encoded_batches <- parallel::parLapply(cl, x = batches, fun = function(x){ encode_batch_post(x, typecast, prog_bar = NULL) })
    
    parallel::stopCluster(cl)
    message(adorn_text("Data JSON Encoded. Beginning POST requests."))
    
  } else {
    pb <- progress::progress_bar$new(total = length(batches),
                                     format = "  JSON Encoding Data for POST [:bar] :percent eta: :eta"
    )
    # pb$tick(0)
    
    encoded_batches <- lapply(batches, function(x) encode_batch_post(x, typecast, prog_bar = pb))
  }
  
  encoded_batches
  
}


encode_batch_post <- function(list_of_lists, typecast, prog_bar){
  
  lol <- vector(mode = 'list', length = length(list_of_lists))
  
  for (idx in 1:length(lol)){
    lol[[idx]] <- list(fields = lapply(list_of_lists[[idx]], 
                                       function(r) if (is.list(r) & length(r[[1]]) > 1) unlist(r) else r))
  }
  
  fields <- list(records = lol)
  
  if (typecast){
    fields['typecast'] <- TRUE
  }
  
  jsonout <- jsonlite::toJSON(fields, 
                              auto_unbox = TRUE,
                              # pretty = TRUE,
                              na = "null")
  
  cln <- gsub("fields\\.\\d?\\d", "fields", jsonout)
  
  if(!is.null(prog_bar)){  
    prog_bar$tick() 
  }
  
  cln
}


post <- function(records, airtable_obj, prog_bar){
  
  response <- httr::POST(attr(airtable_obj, 'request_url'),
                         config = httr::add_headers(
                           Authorization = paste("Bearer", get_airtable_api_key()),
                           `Content-type` = "application/json"
                         ),
                         body = records
  )
  
  if (!httr::status_code(response) %in% c(200)){
    stop(paste0("Error in POST. ", process_error(httr::status_code(response))), call. = FALSE)
  }
  
  Sys.sleep(.21)
  
  prog_bar$tick()
}

vpost <- Vectorize(post, vectorize.args = "records")
