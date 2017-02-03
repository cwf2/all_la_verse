#!/usr/bin/env Rscript --vanilla
#
# Read the output of all_la_verse and try to make a first approximation
# of the graph of intertextual connections, for debugging purposes.
#

#
# Functions
#

itext.density <- Vectorize(
  # for each run id, read the list of scores, return number exceeding cutoff

  function(id, cutoff=8, dens.fun=sum) {

    file_scores <- file.path(dir_scores, paste(id, "txt", sep="."))
    scores <- scan(file_scores, sep="\n", quiet=T)

    dens.fun(scores[scores>=cutoff])
  }, vectorize.args = "id"
)

same.auth <- Vectorize(
  # TRUE if source and target have same author,
  # FALSE otherwise

  function(label) {
    auth <- unlist(strsplit(label, split="~", fixed=T))
    auth <- sub("\\..*", "", auth)
    auth[1] == auth[2]
  }
)

lscale <- function(x) {
  # linear rescaling to the range 0,1

  xmax <- max(x)
  xmin <- min(x)

  (x - xmin) / (xmax - xmin)
}

#
# Main
#

# cutoff - try setting this to 0
cutoff <- 8

# default locations of the data
file_index_nodes <- file.path("output", "index_text.txt")
file_index_edges <- file.path("output", "index_run.txt")
dir_scores <- file.path("output", "scores")


# read the metadata defining the runs and texts

cat("Reading nodes index", file_index_nodes, "\n")
node.id <- read.table(file_index_nodes, header=T, row.names=1)

cat("Reading edges index", file_index_edges, "\n")
edge.id <- read.table(file_index_edges,
  colClasses=c("character", "integer", "integer"),
  header=T
)

# calculate edge weights

cat("Calculating edge weights\n")
edges <- data.frame(
  id = edge.id$id,
  source = edge.id$source,
  target = edge.id$target,
  score = itext.density(edge.id$id, cutoff=cutoff),
  tok = as.numeric(node.id[as.character(edge.id$source), "tokens"]) *
     as.numeric(node.id[as.character(edge.id$target), "tokens"]),
  label = paste(sep="~",
     node.id[as.character(edge.id$source), "label"],
     node.id[as.character(edge.id$target), "label"]
   ),
  stringsAsFactors = F
)
edges$nscore <- round(10^8 * edges$score/edges$tok, digits=2)
edges$scaled <- lscale(edges$nscore)
edges <- edges[order(edges$nscore, decreasing=T),]


# draw histograms
png(
  file=paste("hist-cutoff-", cutoff, ".png", sep=""),
  width=1000,
  height=400
)
par(mfrow=c(1,2))

# same author
hist(edges[same.auth(edges$label), "scaled"],
  breaks = 40,
  xlim = c(0,1),
  main = paste(
    "distribution of scores",
    "same author",
    paste("cutoff", "=", cutoff),
    sep = "\n"
  ),
  xlab = "score")

# different author
hist(edges[! same.auth(edges$label), "scaled"],
     breaks = 40,
     xlim = c(0, 1),
     main = paste(
       "distribution of scores",
       "different authors",
       paste("cutoff", "=", cutoff),
       sep = "\n"
     ),
     xlab = "score")

dev.off()
