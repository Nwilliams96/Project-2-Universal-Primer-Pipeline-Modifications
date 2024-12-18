#!/usr/bin/env Rscript

#Set directory for libraries.
myPaths <- .libPaths()
myPaths <- c(myPaths, '/home1/nathanwi/R/x86_64-pc-linux-gnu-library/4.3')
.libPaths(myPaths)

#Load dependencies
library(tidyverse)
library(lubridate)
library(patchwork)

#This script will load in the data for the cruise that is being uploaded to CMAP. We will convert it into long format.

#Import data
counts <- list.files(pattern = '*corrected_18S_16S_counts_ProPortal.tsv')
counts_df <- lapply(counts, readr::read_tsv) # Import each file and store the data frames in a list
counts <- data.table::rbindlist(counts_df, use.names = TRUE, fill = TRUE) # If you want to combine the data frames into a single data frame, you can use functions like bind_rows

sample_data_list <- list.files(pattern = '*metadata.csv')
sample_data_df <- lapply(sample_data_list, readr::read_csv)
sample_data <- data.table::rbindlist(sample_data_df, use.names = TRUE, fill = TRUE)

#Import all the ASV sequences from the 16S data
files <- list.files(pattern = '*16S.dna-sequences.fasta', full.names = TRUE) # List all files in the directory that match the pattern '*16S.dna-sequences.fasta'

for (file in files) {
  input <- readLines(file)
  # Standardize the output filename
  output_filename <- "prokaryote_asv_sequences.csv"
  # Open the output file
  output <- file(output_filename, "w")
  # Initialize sequence counter
  currentSeq <- 0
  # Process each line of the input file
  for (i in 1:length(input)) {
    if (strtrim(input[i], 1) == ">") {
      # If it's the first sequence, write the sequence header followed by a tab without newline
if (currentSeq == 0) {
  writeLines(paste(input[i], "\t"), output, sep = "")
  currentSeq <- currentSeq + 1
} else {
  # For subsequent sequences, add a newline before the sequence header
  writeLines(paste("\n", input[i], "\t", sep = ""), output, sep = "")
}
} else {
  # Write sequence data directly
  writeLines(paste(input[i]), output, sep = "")
}
}

# Close the output file
close(output)
}

#Import all the ASV sequences from the 18S data
files <- list.files(pattern = '*18S.dna-sequences.fasta', full.names = TRUE) # List all files in the directory that match the pattern '*16S.dna-sequences.fasta'
for (file in files) {
  input <- readLines(file)
  # Replace the entire filename to standardize the output filename
  output_filename <- "eukaryote_asv_sequences.csv"
  # Open the output file
  output <- file(output_filename, "w")
  # Initialize sequence counter
  currentSeq <- 0
  # Process each line of the input file
  for (i in 1:length(input)) {
    if (strtrim(input[i], 1) == ">") {
      # If it's the first sequence, write the sequence header followed by a tab without newline
      if (currentSeq == 0) {
        writeLines(paste(input[i], "\t"), output, sep = "")
        currentSeq <- currentSeq + 1
      } else {
        # For subsequent sequences, add a newline before the sequence header
        writeLines(paste("\n", input[i], "\t", sep = ""), output, sep = "")
      }
    } else {
      # Write sequence data directly
      writeLines(paste(input[i]), output, sep = "")
    }
  }
  
  # Close the output file
  close(output)
}

#Import asv_sequences now that htey have been converted to csv files
prokaryote_asv_sequences <- read.csv("prokaryote_asv_sequences.csv", header=FALSE)
eukaryote_asv_sequences  <- read.csv("eukaryote_asv_sequences.csv",header=FALSE)

#Join together asv sequences
asv_sequences <- bind_rows(eukaryote_asv_sequences,prokaryote_asv_sequences)
asv_sequences <- asv_sequences %>% rename(ASV = V1)
asv_sequences <- write_csv(asv_sequences, "asv_sequences.csv")

#Rearrange asv sequences so that we can work with it
asv_sequences <- read.delim("asv_sequences.csv", sep = "\t", header = T, row.names = NULL) %>% rename(ASV_hash = row.names) 
asv_sequences <- lapply(asv_sequences, gsub, pattern='>', replacement='')
asv_sequences <- lapply(asv_sequences, gsub, pattern=' ', replacement='')
asv_sequences <- as.data.frame(asv_sequences)

#parse out plas to get a yes/no column for whether something came from a plastid or not.
Taxonomy <- counts %>% 
  select(Taxonomy, ProPortal_ASV_Ecotype, ASV_hash)
Taxonomy <- Taxonomy %>%
  mutate(plastid_16S_rRNA = case_when(str_detect(Taxonomy, ":plas") ~ "yes", TRUE ~ "no"))
Taxonomy <- Taxonomy %>% 
  mutate(Source_database = case_when(str_detect(Taxonomy, "d__") ~ "SILVA", TRUE ~ "PR2"))

# This is to create a dataframe for proportal assigned taxa - this is requried for the "source_database" column
ProPortal <- Taxonomy %>% 
  filter(!ProPortal_ASV_Ecotype %in% (NA)) %>% mutate(Source_database = c("ProPortal"))
ProPortal$ProPortal_ASV_Ecotype <- as.character(ProPortal$ProPortal_ASV_Ecotype)
Taxonomy <- Taxonomy %>% 
  filter(ProPortal_ASV_Ecotype %in% (NA))

ProPortal <- ProPortal %>% 
  separate(Taxonomy, c("Domain","Phylum", "Class", "Order", "Family","Genus","Species"), ";")
ProPortal <- lapply(ProPortal, gsub, pattern=c('d__'), replacement='')
ProPortal <- lapply(ProPortal, gsub, pattern=c("p__"), replacement='')
ProPortal <- lapply(ProPortal, gsub, pattern=c("c__"), replacement='')
ProPortal <- lapply(ProPortal, gsub, pattern=c("o__"), replacement='')
ProPortal <- lapply(ProPortal, gsub, pattern=c("f__"), replacement='')
ProPortal <- lapply(ProPortal, gsub, pattern=c("g__"), replacement='')
ProPortal <- lapply(ProPortal, gsub, pattern=c("s__"), replacement='')
ProPortal <- as.data.frame(ProPortal)

# This is to create a dataframe for SILVA assigned taxa - this is requried for the "source_database" column
SILVA <- Taxonomy %>% 
  filter(Source_database %in% c("SILVA"))
SILVA <- SILVA %>% 
  separate(Taxonomy, c("Domain","Phylum", "Class", "Order", "Family","Genus","Species"), ";")
SILVA <- lapply(SILVA, gsub, pattern=c('d__'), replacement='')
SILVA <- lapply(SILVA, gsub, pattern=c("p__"), replacement='')
SILVA <- lapply(SILVA, gsub, pattern=c("c__"), replacement='')
SILVA <- lapply(SILVA, gsub, pattern=c("o__"), replacement='')
SILVA <- lapply(SILVA, gsub, pattern=c("f__"), replacement='')
SILVA <- lapply(SILVA, gsub, pattern=c("g__"), replacement='')
SILVA <- lapply(SILVA, gsub, pattern=c("s__"), replacement='')
SILVA <- as.data.frame(SILVA)

# This is to create a dataframe for PR2 assigned taxa - this is requried for the "source_database" column
PR2 <- Taxonomy %>% 
  filter(Source_database %in% c("PR2"))
PR2 <- PR2 %>% 
  separate(Taxonomy, c("Domain", "Supergroup","Division", "Class", "Order", "Family","Genus","Species"), ";")
PR2 <- lapply(PR2, gsub, pattern = c(":plas"), replacement = '')
PR2 <- as.data.frame(PR2)

#Join all the Taxonomy together
Taxonomy <- bind_rows(SILVA,PR2,ProPortal)

#Left join taxonomy to asv_sequences
Taxonomy <- Taxonomy %>% 
  left_join(asv_sequences)

#Join asv table to Taxonomy}
counts <- Taxonomy %>% 
  left_join(counts)

#ASV Data Long
counts_long <- gather(data = counts, key = SampleID, value = Corrected_Squence_Counts, -c(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15))

#Join sample data}
asv_long <- counts_long %>% left_join(sample_data)

#Max Abundance}
asv_long <- asv_long %>% rename(ASV_hash = ASV_hash)

Samples.that.dont.match.SD <- asv_long %>% 
  ungroup() %>% filter(Cruise_ID %in% (NA)) %>% 
  distinct(SampleID, .keep_all = TRUE)
SampleIDs <-  asv_long %>% ungroup() %>% 
  distinct(SampleID, .keep_all = FALSE)

write_csv(Samples.that.dont.match.SD, "Samples_with_no_sample_data.csv")

#Remove Samples.that.dont.match.SD or any other unwanted blanks etc.
asv_long <- asv_long %>% 
  filter(!SampleID %in% c("DNA-tag-blank","cDNA-tag-blank"))

asv_long <- asv_long %>% 
  ungroup() %>% 
  filter(!Cruise %in% (NA))

#Calculate Relative Abundance
asv_long <- asv_long %>% 
  filter(!Corrected_Squence_Counts %in% (0)) %>%
  group_by(Latitude, Longitude, Depth, ASV_hash) %>%
  mutate(Average.Corrected_Squence_Counts = mean(Corrected_Squence_Counts)) %>%
  ungroup() %>%
  filter(!Replicate %in% c("B")) %>%
  select(-Corrected_Squence_Counts)

asv_long <- asv_long %>% 
  rename(Corrected_Squence_Counts = Average.Corrected_Squence_Counts)

asv_long <- asv_long %>% 
  group_by(SampleID) %>% 
  mutate(TC = sum(Corrected_Squence_Counts)) %>% 
  group_by(SampleID,ASV) %>% 
  mutate(Relative_Abundance = (Corrected_Squence_Counts/TC))

Check <- asv_long %>% 
  ungroup() %>% 
  group_by(SampleID) %>% 
  summarise(Check = sum(Relative_Abundance))

#Make Sequence Type Column
asv_long <- asv_long %>% mutate(Plas_Domain = paste(plastid_16S_rRNA, Domain, sep = "_"))
Prokaryotic_16S <- asv_long %>% filter(Plas_Domain %in% c("no_Bacteria","no_Archaea")) %>% mutate(Sequence_Type = "Prokaryotic_16S")
Chloroplast_16S <- asv_long %>% filter(Plas_Domain %in% c("yes_Eukaryota"))  %>% mutate(Sequence_Type = "Chloroplast_16S")
Eukaryote_18S   <- asv_long %>% filter(Plas_Domain %in% c("no_Eukaryota"))  %>% mutate(Sequence_Type = "Eukaryote_18S")
Unassigned      <- asv_long %>% filter(Plas_Domain %in% c("no_Unassigned"))  %>% mutate(Sequence_Type = "Unassigned")

asv_long <- bind_rows(Prokaryotic_16S,Chloroplast_16S,Eukaryote_18S,Unassigned)

#Calculate the counts for each sample, and then remove anything with a maximum read count of under 5000
Sample_Read_Count_Total <- asv_long %>% ungroup() %>% group_by(SampleID) %>% summarise(Count_Total = sum(Corrected_Squence_Counts))
Below.5000 <- Sample_Read_Count_Total %>% filter(Count_Total <= 5000)
Below.5000.List <- Below.5000 %>% pull(SampleID)
asv_long <- asv_long %>% filter(!SampleID %in% Below.5000.List)

#Tidy order of columns and what's included in final sheet
asv_long <- asv_long %>% 
  select(SampleID, Domain, Supergroup, Division, Phylum, Class, Order, Family, Genus, Species, ProPortal_ASV_Ecotype, Sequence_Type, plastid_16S_rRNA, ASV_hash, ASV, Corrected_Squence_Counts, Relative_Abundance, Source_database, Cruise, Cruise_ID, Station, Replicate, Latitude, Longitude, Date, Time, Date_Time, Day, Month, Year, Depth, Bottom_Depth, Temperature, Salinity, Oxygen, Silicate, NO2, NO3, NH3, PO4, DOC, TOC, PAR, Chlorophyll, DCM, Season, Longhurst_Short, Longhurst_Long, Predicted_Euphotic_Depth)

#Last thing is to remove 0's for our use to prevent having such a large file
asv_long <- asv_long %>% filter(!Corrected_Squence_Counts %in% (0))


#CMAP Specific
asv_long_CMAP <- asv_long
asv_long_CMAP <- asv_long_CMAP %>% rename(time = Date_Time)
asv_long_CMAP <- asv_long_CMAP %>% rename(lat = Latitude)
asv_long_CMAP <- asv_long_CMAP %>% rename(lon = Longitude)
asv_long_CMAP <- asv_long_CMAP %>% rename(depth = Depth)
asv_long_CMAP <- asv_long_CMAP %>% select(time, lat, lon, depth, SampleID, Domain, Supergroup, Division, Phylum, Class, Order, Family, Genus, Species, ProPortal_ASV_Ecotype, ASV_hash, ASV, Relative_Abundance, Corrected_Squence_Counts, Source_database, Cruise, Cruise_ID, Station, Replicate, Day, Month, Year, Bottom_Depth, Temperature, Salinity, Oxygen, Silicate, NO2, NO3, NH3, PO4, DOC, TOC, PAR, Chlorophyll, DCM, Season, Longhurst_Short, Longhurst_Long, Predicted_Euphotic_Depth)


#Write asv_long CMAP
write_csv(asv_long_CMAP,'asv_long_CMAP.csv')

#Write asv long
write_csv(asv_long,'asv_long.csv')

q()
