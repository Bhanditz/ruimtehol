#' @title Build a Starspace model to be used for classification purposes
#' @description Build a Starspace model to be used for classification purposes
#' @param x a character vector of text where tokens are separated by spaces
#' @param y a character vector of classes to predict or a list with the same length of \code{x} with several classes for each respective element of \code{x}
#' @param model name of the model which will be saved, passed on to \code{\link{starspace}}
#' @param early_stopping the percentage of the data that will be used as training data. If set to a value smaller than 1, 1-\code{early_stopping} percentage of the data which will be used as the validation set and early stopping will be executed. Defaults to 0.75.
#' @param ... further arguments passed on to \code{\link{starspace}} except file, trainMode and fileFormat
#' @export
#' @return an object of class \code{textspace} as returned by \code{\link{starspace}}.
#' @examples 
#' data(dekamer, package = "ruimtehol")
#' dekamer <- subset(dekamer, depotdat < as.Date("2017-02-01"))
#' dekamer$text <- strsplit(dekamer$question, "\\W")
#' dekamer$text <- lapply(dekamer$text, FUN = function(x) setdiff(x, ""))
#' dekamer$text <- sapply(dekamer$text, 
#'                        FUN = function(x) paste(x, collapse = " "))
#' dekamer$question_theme_main <- gsub(" ", "-", dekamer$question_theme_main)
#' 
#' set.seed(123456789)
#' model <- embed_tagspace(x = tolower(dekamer$text), 
#'                         y = dekamer$question_theme_main, 
#'                         early_stopping = 0.8, 
#'                         dim = 10, minCount = 5)
#' plot(model)
#' predict(model, "de nmbs heeft het treinaanbod uitgebreid", k = 3)
#' predict(model, "de migranten komen naar europa, in asielcentra ...")
#' starspace_embedding(model, "de nmbs heeft het treinaanbod uitgebreid")
#' starspace_embedding(model, "__label__MIGRATIEBELEID", type = "ngram")
#' 
#' dekamer$question_themes <- gsub(" ", "-", dekamer$question_theme)
#' dekamer$question_themes <- strsplit(dekamer$question_themes, split = ",")
#' set.seed(123456789)
#' model <- embed_tagspace(x = tolower(dekamer$text), 
#'                         y = dekamer$question_themes, 
#'                         early_stopping = 0.8,
#'                         dim = 50, minCount = 2, epoch = 50)
#' plot(model)
#' predict(model, "de nmbs heeft het treinaanbod uitgebreid")
#' predict(model, "de migranten komen naar europa , in asielcentra ...")
#' embeddings_labels <- as.matrix(model, type = "labels")
#' emb <- starspace_embedding(model, "de nmbs heeft het treinaanbod uitgebreid")
#' embedding_similarity(emb, embeddings_labels, type = "cosine", top_n = 5)
embed_tagspace <- function(x, y, model = "tagspace.bin", early_stopping = 0.75, ...) {
  stopifnot(early_stopping >= 0 && early_stopping <= 1)
  ldots <- list(...)
  filename <- tempfile(pattern = "textspace_", fileext = ".txt")
  filename_validation <- tempfile(pattern = "textspace_validation_", fileext = ".txt")
  on.exit({
    if(file.exists(filename)) file.remove(filename) 
    if(file.exists(filename_validation)) file.remove(filename_validation)
  })
  label <- "__label__"
  if("label" %in% names(ldots)){
    label <- ldots$label
  }
  if(is.list(y)){
    targets <- sapply(y, FUN=function(x) paste(paste(label, x, sep = ""), collapse = " "))
  }else{
    targets <- paste(label, y, sep = "")
  }
  x <- paste(targets, x)
  if(early_stopping < 1){
    idx <- sample.int(n = length(x), size = round(early_stopping * length(x)))
    writeLines(text = x[idx], con = filename)
    writeLines(text = x[-idx], con = filename_validation)
    starspace(model = model, file = filename, trainMode = 0, fileFormat = "fastText", validationFile = filename_validation, ...)
  }else{
    writeLines(text = x, con = filename)
    starspace(model = model, file = filename, trainMode = 0, fileFormat = "fastText", ...)
  }
}

#' @title Build a Starspace model which calculates word embeddings
#' @description Build a Starspace model which calculates word embeddings
#' @param x a character vector of text where tokens are separated by spaces
#' @param model name of the model which will be saved, passed on to \code{\link{starspace}}
#' @param early_stopping the percentage of the data that will be used as training data. If set to a value smaller than 1, 1-\code{early_stopping} percentage of the data which will be used as the validation set and early stopping will be executed. Defaults to 0.75.
#' @param ... further arguments passed on to \code{\link{starspace}} except file, trainMode and fileFormat
#' @export
#' @return an object of class \code{textspace} as returned by \code{\link{starspace}}.
#' @examples 
#' library(udpipe)
#' data(brussels_reviews, package = "udpipe")
#' x <- subset(brussels_reviews, language == "nl")
#' x <- strsplit(x$feedback, "\\W")
#' x <- lapply(x, FUN = function(x) setdiff(x, ""))
#' x <- sapply(x, FUN = function(x) paste(x, collapse = " "))
#' x <- tolower(x)
#' 
#' set.seed(123456789)
#' model <- embed_wordspace(x, early_stopping = 0.9, 
#'                          dim = 15, ws = 7, epoch = 10, minCount = 5, ngrams = 1,
#'                          maxTrainTime = 2) ## maxTrainTime only set for CRAN
#' plot(model)
#' wordvectors <- as.matrix(model)
#' 
#' mostsimilar <- embedding_similarity(wordvectors, wordvectors["weekend", ])
#' head(sort(mostsimilar[, 1], decreasing = TRUE), 10)
#' mostsimilar <- embedding_similarity(wordvectors, wordvectors["vriendelijk", ])
#' head(sort(mostsimilar[, 1], decreasing = TRUE), 10)
#' mostsimilar <- embedding_similarity(wordvectors, wordvectors["grote", ])
#' head(sort(mostsimilar[, 1], decreasing = TRUE), 10)
embed_wordspace <- function(x, model = "wordspace.bin", early_stopping = 0.75, ...) {
  stopifnot(early_stopping >= 0 && early_stopping <= 1)
  ldots <- list(...)
  filename <- tempfile(pattern = "textspace_", fileext = ".txt")   
  filename_validation <- tempfile(pattern = "textspace_validation_", fileext = ".txt")
  on.exit({
    if(file.exists(filename)) file.remove(filename) 
    if(file.exists(filename_validation)) file.remove(filename_validation)
  })
  label <- "__label__"
  if("label" %in% names(ldots)){
    label <- ldots$label
  }
  if(early_stopping < 1){
    idx <- sample.int(n = length(x), size = round(early_stopping * length(x)))
    writeLines(text = x[idx], con = filename)
    writeLines(text = x[-idx], con = filename_validation)
    starspace(model = model, file = filename, trainMode = 5, fileFormat = "fastText", validationFile = filename_validation, ...)
  }else{
    writeLines(text = x, con = filename)
    starspace(model = model, file = filename, trainMode = 5, fileFormat = "fastText", ...)
  }
}

#' @title Build a Starspace model to be used for sentence embedding
#' @description Build a Starspace model to be used for sentence embedding
#' @param x a data.frame with sentences containg the columns doc_id, sentence_id and token 
#' The doc_id is just an article or document identifier, 
#' the sentence_id column is a character field which contains words which are separated by a space and should not contain any tab characters
#' @param model name of the model which will be saved, passed on to \code{\link{starspace}}
#' @param early_stopping the percentage of the data that will be used as training data. If set to a value smaller than 1, 1-\code{early_stopping} percentage of the data which will be used as the validation set and early stopping will be executed. Defaults to 0.75.
#' @param ... further arguments passed on to \code{\link{starspace}} except file, trainMode and fileFormat
#' @export
#' @return an object of class \code{textspace} as returned by \code{\link{starspace}}.
#' @examples 
#' library(udpipe)
#' data(brussels_reviews_anno, package = "udpipe")
#' x <- subset(brussels_reviews_anno, language == "nl")
#' x$token <- x$lemma
#' x <- x[, c("doc_id", "sentence_id", "token")]
#' set.seed(123456789)
#' model <- embed_sentencespace(x, dim = 15, epoch = 15, 
#'                              negSearchLimit = 1, maxNegSamples = 2)
#' plot(model)
#' sentences <- c("ook de keuken zijn zeer goed uitgerust .",
#'                "het appartement zijn met veel smaak inrichten en zeer proper .")
#' predict(model, sentences, type = "embedding")
#' starspace_embedding(model, sentences)
#' 
#' \dontrun{
#' library(udpipe)
#' data(dekamer, package = "ruimtehol")
#' x <- udpipe(dekamer$question, "dutch", tagger = "none", parser = "none", trace = 100)
#' x <- x[, c("doc_id", "sentence_id", "sentence", "token")]
#' set.seed(123456789)
#' model <- embed_sentencespace(x, dim = 15, epoch = 5, minCount = 5)
#' plot(model)
#' predict(model, "Wat zijn de cijfers qua doorstroming van 2016?", 
#'         basedoc = unique(x$sentence))
#' 
#' embeddings <- starspace_embedding(model, unique(x$sentence), type = "document")
#' dim(embeddings)
#' 
#' sentence <- "Wat zijn de cijfers qua doorstroming van 2016?"
#' embedding_sentence <- starspace_embedding(model, sentence, type = "document")
#' mostsimilar <- embedding_similarity(embeddings, embedding_sentence)
#' head(sort(mostsimilar[, 1], decreasing = TRUE), 3)
#' 
#' ## clean up for cran
#' file.remove(list.files(pattern = ".udpipe$"))
#' }
embed_sentencespace <- function(x, model = "sentencespace.bin", early_stopping = 0.75, ...) {
  stopifnot(early_stopping >= 0 && early_stopping <= 1)
  stopifnot(is.data.frame(x))
  stopifnot(all(c("doc_id", "sentence_id", "token") %in% colnames(x)))
  ldots <- list(...)
  filename <- tempfile(pattern = "textspace_", fileext = ".txt")   
  filename_validation <- tempfile(pattern = "textspace_validation_", fileext = ".txt")
  on.exit({
    if(file.exists(filename)) file.remove(filename) 
    if(file.exists(filename_validation)) file.remove(filename_validation)
  })
  label <- "__label__"
  if("label" %in% names(ldots)){
    label <- ldots$label
  }
  x <- split(x, f = x$doc_id)
  x <- sapply(x, FUN=function(tokens){
    sentences <- split(tokens, tokens$sentence_id)
    sentences <- sapply(sentences, FUN=function(x) paste(x$token, collapse = " "))
    paste(sentences, collapse = " \t ")
  })
  if(early_stopping < 1){
    idx <- sample.int(n = length(x), size = round(early_stopping * length(x)))
    writeLines(text = x[idx], con = filename)
    writeLines(text = x[-idx], con = filename_validation)
    starspace(model = model, file = filename, trainMode = 3, fileFormat = "labelDoc", validationFile = filename_validation, ...)
  }else{
    writeLines(text = x, con = filename)
    starspace(model = model, file = filename, trainMode = 3, fileFormat = "labelDoc", ...)
  }
}

#' @title Build a Starspace model for learning the mapping between sentences and articles (articlespace)
#' @description Build a Starspace model for learning the mapping between sentences and articles (articlespace)
#' @param x a data.frame with sentences containing the columns doc_id, sentence_id and token 
#' The doc_id is just an article or document identifier, 
#' the sentence_id column is a character field which contains words which are separated by a space and should not contain any tab characters
#' @param model name of the model which will be saved, passed on to \code{\link{starspace}}
#' @param early_stopping the percentage of the data that will be used as training data. If set to a value smaller than 1, 1-\code{early_stopping} percentage of the data which will be used as the validation set and early stopping will be executed. Defaults to 0.75.
#' @param ... further arguments passed on to \code{\link{starspace}} except file, trainMode and fileFormat
#' @export
#' @return an object of class \code{textspace} as returned by \code{\link{starspace}}.
#' @examples 
#' library(udpipe)
#' data(brussels_reviews_anno, package = "udpipe")
#' x <- subset(brussels_reviews_anno, language == "nl")
#' x$token <- x$lemma
#' x <- x[, c("doc_id", "sentence_id", "token")]
#' set.seed(123456789)
#' model <- embed_articlespace(x, early_stopping = 1,
#'                             dim = 25, epoch = 25, minCount = 2,
#'                             negSearchLimit = 1, maxNegSamples = 2)
#' plot(model)
#' sentences <- c("ook de keuken zijn zeer goed uitgerust .",
#'                "het appartement zijn met veel smaak inrichten en zeer proper .")
#' predict(model, sentences, type = "embedding")
#' starspace_embedding(model, sentences)
#' 
#' \dontrun{
#' library(udpipe)
#' data(dekamer, package = "ruimtehol")
#' dekamer <- subset(dekamer, question_theme_main == "DEFENSIEBELEID")
#' x <- udpipe(dekamer$question, "dutch", tagger = "none", parser = "none", trace = 100)
#' x <- x[, c("doc_id", "sentence_id", "sentence", "token")]
#' set.seed(123456789)
#' model <- embed_articlespace(x, early_stopping = 0.8, dim = 15, epoch = 5, minCount = 5)
#' plot(model)
#' 
#' embeddings <- starspace_embedding(model, unique(x$sentence), type = "document")
#' dim(embeddings)
#' 
#' sentence <- "Wat zijn de cijfers qua doorstroming van 2016?"
#' embedding_sentence <- starspace_embedding(model, sentence, type = "document")
#' mostsimilar <- embedding_similarity(embeddings, embedding_sentence)
#' head(sort(mostsimilar[, 1], decreasing = TRUE), 3)
#' 
#' ## clean up for cran
#' file.remove(list.files(pattern = ".udpipe$"))
#' }
embed_articlespace <- function(x, model = "articlespace.bin", early_stopping = 0.75, ...) {
  stopifnot(early_stopping >= 0 && early_stopping <= 1)
  stopifnot(is.data.frame(x))
  stopifnot(all(c("doc_id", "sentence_id", "token") %in% colnames(x)))
  ldots <- list(...)
  filename <- tempfile(pattern = "textspace_", fileext = ".txt")   
  filename_validation <- tempfile(pattern = "textspace_validation_", fileext = ".txt")
  on.exit({
    if(file.exists(filename)) file.remove(filename) 
    if(file.exists(filename_validation)) file.remove(filename_validation)
  })
  label <- "__label__"
  if("label" %in% names(ldots)){
    label <- ldots$label
  }
  x <- split(x, f = x$doc_id)
  x <- sapply(x, FUN=function(tokens){
    sentences <- split(tokens, tokens$sentence_id)
    sentences <- sapply(sentences, FUN=function(x) paste(x$token, collapse = " "))
    paste(sentences, collapse = " \t ")
  })
  if(early_stopping < 1){
    idx <- sample.int(n = length(x), size = round(early_stopping * length(x)))
    writeLines(text = x[idx], con = filename)
    writeLines(text = x[-idx], con = filename_validation)
    starspace(model = model, file = filename, trainMode = 2, fileFormat = "labelDoc", validationFile = filename_validation, ...)
  }else{
    writeLines(text = x, con = filename)
    starspace(model = model, file = filename, trainMode = 2, fileFormat = "labelDoc", ...)
  }
}

#' @title Build a Starspace model for content-based recommendation
#' @description Build a Starspace model for content-based recommendation (docspace). For example a user clicks on a webpage and this webpage contains a bunch or words.
#' @param x a data.frame with user interest containing the columns user_id, doc_id and text 
#' The user_id is an identifier of a user
#' The doc_id is just an article or document identifier 
#' the text column is a character field which contains words which are part of the doc_id, words should be separated by a space and 
#' should not contain any tab characters
#' @param model name of the model which will be saved, passed on to \code{\link{starspace}}
#' @param early_stopping the percentage of the data that will be used as training data. If set to a value smaller than 1, 1-\code{early_stopping} percentage of the data which will be used as the validation set and early stopping will be executed. Defaults to 0.75.
#' @param ... further arguments passed on to \code{\link{starspace}} except file, trainMode and fileFormat
#' @export
#' @return an object of class \code{textspace} as returned by \code{\link{starspace}}.
#' @examples 
#' library(udpipe)
#' data(dekamer, package = "ruimtehol")
#' data(dekamer_theme_terminology, package = "ruimtehol")
#' ## Which person is interested in which theme (aka document)
#' x <- table(dekamer$aut_person, dekamer$question_theme_main)
#' x <- as.data.frame(x)
#' colnames(x) <- c("user_id", "doc_id", "freq")
#' ## Characterise the themes (aka document)
#' docs <- split(dekamer_theme_terminology, dekamer_theme_terminology$theme)
#' docs <- lapply(docs, FUN=function(x){
#'   data.frame(theme = x$theme[1], text = paste(x$term, collapse = " "), 
#'              stringsAsFactors=FALSE)
#' })
#' docs <- do.call(rbind, docs)
#' 
#' ## Build a model
#' train <- merge(x, docs, by.x = "doc_id", by.y = "theme")
#' train <- subset(train, user_id %in% sample(levels(train$user_id), 4))
#' set.seed(123456789)
#' model <- embed_docspace(train, dim = 10, early_stopping = 1)
#' plot(model)
embed_docspace <- embed_webpage <- function(x, model = "docspace.bin", early_stopping = 0.75, ...) {
  ## user clicks on a web page which has content
  ## trainMode 1, fileFormat labelDoc
  stopifnot(early_stopping >= 0 && early_stopping <= 1)
  stopifnot(is.data.frame(x))
  stopifnot(all(c("user_id", "doc_id", "text") %in% colnames(x)))
  ldots <- list(...)
  filename <- tempfile(pattern = "textspace_", fileext = ".txt")   
  filename_validation <- tempfile(pattern = "textspace_validation_", fileext = ".txt")
  on.exit({
    if(file.exists(filename)) file.remove(filename) 
    if(file.exists(filename_validation)) file.remove(filename_validation)
  })
  label <- "__label__"
  if("label" %in% names(ldots)){
    label <- ldots$label
  }
  x <- split(x, f = x$user_id)
  x <- sapply(x, FUN=function(userdata){
    paste(userdata$text, collapse = " \t ")
  })
  if(early_stopping < 1){
    idx <- sample.int(n = length(x), size = round(early_stopping * length(x)))
    writeLines(text = x[idx], con = filename)
    writeLines(text = x[-idx], con = filename_validation)
    starspace(model = model, file = filename, trainMode = 1, fileFormat = "labelDoc", validationFile = filename_validation, ...)
  }else{
    writeLines(text = x, con = filename)
    starspace(model = model, file = filename, trainMode = 1, fileFormat = "labelDoc", ...)
  }
}

#' @title Build a Starspace model for interest-based recommendation
#' @description Build a Starspace model for interest-based recommendation (pagespace). For example a user clicks on a webpage.
#' @param x a list where each list element contains a character vector of pages which the user was interested in
#' @param model name of the model which will be saved, passed on to \code{\link{starspace}}
#' @param early_stopping the percentage of the data that will be used as training data. If set to a value smaller than 1, 1-\code{early_stopping} percentage of the data which will be used as the validation set and early stopping will be executed. Defaults to 0.75.
#' @param ... further arguments passed on to \code{\link{starspace}} except file, trainMode and fileFormat
#' @export
#' @return an object of class \code{textspace} as returned by \code{\link{starspace}}.
#' @examples 
#' data(dekamer, package = "ruimtehol")
#' x <- subset(dekamer, !is.na(question_theme))
#' x <- strsplit(x$question_theme, ",")
#' x <- lapply(x, FUN=unique)
#' str(x)
#' set.seed(123456789)
#' model <- embed_pagespace(x, dim = 5, epoch = 5, minCount = 10, label = "__THEME__")
#' plot(model)
#' predict(model, "__THEME__MARINE __THEME__DEFENSIEBELEID")
#'  
#' pagevectors <- as.matrix(model)
#' 
#' mostsimilar <- embedding_similarity(pagevectors, 
#'                                     pagevectors["__THEME__MIGRATIEBELEID", ])
#' head(sort(mostsimilar[, 1], decreasing = TRUE), 3)
#' mostsimilar <- embedding_similarity(pagevectors, 
#'                                     pagevectors["__THEME__DEFENSIEBELEID", ])
#' head(sort(mostsimilar[, 1], decreasing = TRUE), 3)
embed_pagespace <- embed_clicks <- function(x, model = "pagespace.bin", early_stopping = 0.75, ...) {
  ## user clicks or is fan of a webpage
  ## trainMode 1
  stopifnot(early_stopping >= 0 && early_stopping <= 1)
  stopifnot(is.list(x))
  stopifnot(all(sapply(x, FUN=is.character)))
  ldots <- list(...)
  filename <- tempfile(pattern = "textspace_", fileext = ".txt")   
  filename_validation <- tempfile(pattern = "textspace_validation_", fileext = ".txt")
  on.exit({
    if(file.exists(filename)) file.remove(filename) 
    if(file.exists(filename_validation)) file.remove(filename_validation)
  })
  label <- "__label__"
  if("label" %in% names(ldots)){
    label <- ldots$label
  }
  x <- sapply(x, FUN=function(x){
    pages <- sprintf("%s%s", label, gsub("[[:space:]]", "", unique(x))) 
    paste(pages, collapse = " ")
  })
  if(early_stopping < 1){
    idx <- sample.int(n = length(x), size = round(early_stopping * length(x)))
    writeLines(text = x[idx], con = filename)
    writeLines(text = x[-idx], con = filename_validation)
    starspace(model = model, file = filename, trainMode = 1, fileFormat = "fastText", validationFile = filename_validation, ...)
  }else{
    writeLines(text = x, con = filename)
    starspace(model = model, file = filename, trainMode = 1, fileFormat = "fastText", ...)
  }
}


#' @title Build a Starspace model for entity relationship completion
#' @description Build a Starspace model for entity relationship completion (graphspace). 
#' @param x a data.frame with columns entity_head, entity_tail and relation indicating the relation between the head and tail entity
#' @param model name of the model which will be saved, passed on to \code{\link{starspace}}
#' @param early_stopping the percentage of the data that will be used as training data. If set to a value smaller than 1, 1-\code{early_stopping} percentage of the data which will be used as the validation set and early stopping will be executed. Defaults to 0.75.
#' @param ... further arguments passed on to \code{\link{starspace}} except file, trainMode and fileFormat
#' @export
#' @return an object of class \code{textspace} as returned by \code{\link{starspace}}.
#' @examples 
#' ## Example on Freebase
#' filename <- paste(
#'   "https://raw.githubusercontent.com/bnosac-dev/GraphEmbeddings/master/",
#'   "diffbot_data/FB15k/freebase_mtr100_mte100-train.txt", 
#'   sep = "")
#' x <- read.delim(filename, header = FALSE, nrows = 1000,  
#'                 col.names = c("entity_head", "relation", "entity_tail"),
#'                 stringsAsFactors = FALSE)
#' head(x)
#' 
#' set.seed(123456789)
#' model <- embed_entityrelationspace(x, dim = 50)
#' plot(model)
#' 
#' predict(model, "/m/027rn /location/country/form_of_government")
#' 
#' ## Also add reverse relation
#' x_reverse <- x
#' colnames(x_reverse) <- c("entity_tail", "relation", "entity_head")
#' x_reverse$relation <- sprintf("REVERSE_%s", x_reverse$relation)
#' 
#' relations <- rbind(x, x_reverse)
#' set.seed(123456789)
#' model <- embed_entityrelationspace(relations, dim = 50)
#' predict(model, "/m/027rn /location/country/form_of_government")
#' predict(model, "/m/06cx9 REVERSE_/location/country/form_of_government")
embed_entityrelationspace <- function(x, model = "graphspace.bin", early_stopping = 0.75, ...) {
  stopifnot(early_stopping >= 0 && early_stopping <= 1)
  stopifnot(is.data.frame(x))
  stopifnot(all(c("entity_head", "entity_tail", "relation") %in% colnames(x)))
  ldots <- list(...)
  filename <- tempfile(pattern = "textspace_", fileext = ".txt")   
  filename_validation <- tempfile(pattern = "textspace_validation_", fileext = ".txt")
  on.exit({
    if(file.exists(filename)) file.remove(filename) 
    if(file.exists(filename_validation)) file.remove(filename_validation)
  })
  label <- "__label__"
  if("label" %in% names(ldots)){
    label <- ldots$label
  }
  x <- sprintf("%s\t%s\t%s%s", x$entity_head, x$relation, label, x$entity_tail)
  if(early_stopping < 1){
    idx <- sample.int(n = length(x), size = round(early_stopping * length(x)))
    writeLines(text = x[idx], con = filename)
    writeLines(text = x[-idx], con = filename_validation)
    starspace(model = model, file = filename, trainMode = 0, fileFormat = "fastText", validationFile = filename_validation, ...)
  }else{
    writeLines(text = x, con = filename)
    starspace(model = model, file = filename, trainMode = 0, fileFormat = "fastText", ...)
  }
}


if(FALSE){
  embed_imagespace <- function() {
    .NotYetImplemented()
  }
  TagSpace <- embed_tagspace
  WordSpace <- embed_wordspace
  SentenceSpace <- embed_sentencespace
  ArticleSpace <- embed_articlespace
  DocSpace <- embed_webpage <- embed_docspace
  PageSpace <- embed_clicks <- embed_pagespace
  GraphSpace <- embed_entityrelationspace
  ImageSpace <- embed_imagespace
}
