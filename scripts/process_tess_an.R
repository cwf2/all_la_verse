#!/usr/bin/env Rscript --vanilla
#
# Read the output of all_la_verse and try to make a first approximation 
# of the graph of intertextual connections, for debugging purposes.
#

#
# Variables:
#

# default locations of the data
file_index_nodes <- file.path("output", "index_text.txt")
file_index_edges <- file.path("output", "index_run.txt")
dir_scores <- file.path("output", "scores")

# default locations for output
dir_output <- file.path("output", "gephi")
filename_nodes <- "nodes.csv"
filename_edges <- "edges.csv"

#
# Functions
#

nikolaev <- Vectorize(
  # for each run id, read the list of scores, return number exceeding cutoff
  
  function(id, cutoff=8) { 
  
    file_scores <- file.path(dir_scores, paste(id, "txt", sep="."))
    scores <- scan(file_scores, sep="\n", quiet=T)
    
    return(sum(scores>cutoff))
  }
)

#
# Main 
#

# read the metadata defining the runs and texts

cat("Reading nodes index", file_index_nodes, "\n")
nodes <- read.table(file_index_nodes, header=T, row.names=1)

cat("Reading edges index", file_index_edges, "\n")
edges <- read.table(file_index_edges,
  colClasses=c("character", "integer", "integer"), 
  header=T, row.names=1
)

# calculate edge weights

cat("Calculating edge weights\n")
edges <- cbind(edges, 
   score=nikolaev(row.names(edges)),
   tok=as.numeric(nodes[as.character(edges$source), "tokens"]) *
     as.numeric(nodes[as.character(edges$target), "tokens"]),
   label=paste(sep="~",
     nodes[as.character(edges$source), "label"],
     nodes[as.character(edges$target), "label"]
   )
)
edges <- cbind(edges,
  nscore = round(10^8 * edges$score/edges$tok, digits=2)
)
edges <- edges[order(edges$nscore, decreasing=T),]

# Calculate some interesting features of the texts,
#  - we might look later to see how these relate to the scores

cat("Calculating text features\n")
feat <- data.frame(
  tok_s=as.numeric(nodes[as.character(edges$source), "tokens"]),
  tok_t=as.numeric(nodes[as.character(edges$target), "tokens"]),
  stm_s=as.numeric(nodes[as.character(edges$source), "stems"]),
  stm_t=as.numeric(nodes[as.character(edges$target), "stems"]),
  lin_s=nodes[as.character(edges$source), "lines"],
  lin_t=nodes[as.character(edges$target), "lines"],
  phr_s=nodes[as.character(edges$source), "phrases"],
  phr_t=nodes[as.character(edges$target), "phrases"],
  ttw_s=nodes[as.character(edges$source), "ttr_w"],
  ttw_t=nodes[as.character(edges$target), "ttr_w"],
  tts_s=nodes[as.character(edges$source), "ttr_s"],
  tts_t=nodes[as.character(edges$target), "ttr_s"],
  row.names=row.names(edges)
)

#
# Write output
# 

# create output directory if it doesn't exist
if (! dir.exists(dir_output)) {
  dir.create(dir_output)
}

# the nodes table, in Gephi format

file_output_nodes <- file.path(dir_output, filename_nodes)
cat("Writing nodes table", file_output_nodes, "\n")

write.table(file=file_output_nodes,
  x=data.frame(
    id=as.integer(row.names(nodes)),
    nodes[,c("label", "auth", "date", "tokens", "phrases", "lines")]),
  sep=",",
  row.names=F
)

# the edges table, in Gephi format

file_output_edges <- file.path(dir_output, filename_edges)
cat("Writing edges table", file_output_edges, "\n")

write.table(file=file_output_edges,
  x=data.frame(
    id=as.integer(row.names(edges)),
    source=edges$source,
    target=edges$target,
    label=edges$label,
    weight=edges$nscore
  ),
  sep=",",
  row.names=F
)
