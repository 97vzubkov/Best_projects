#import of all needed libraries
#check package for existence
#if the nedeed package does not exist -> install it and then import it
#if the nedeed package exists -> just import it

package_names = c('ggplot2','caret','psych','cluster','kmed','wesanderson', 'plyr', 
                  'dplyr', 'scales','arulesViz','MASS','clustMixType','gridExtra'
                  )

for (pac_name in package_names){
  installed_pack<-installed.packages()[,1]
  if(!is.element(pac_name, installed_pack)){
    install.packages(pac_name)
  }
  library(pac_name, character.only=TRUE)
}

RNGkind(sample.kind = "Rounding")

#functions
segmentCharacter <- function(segment){
  
  #add cluster assignment to the initial dataset
  segmentCust = cbind(custData, as.data.frame(segment))
  colnames(segmentCust)[6] = 'Segment'
  
  segmentCust[,'Segment'] = as.factor(segmentCust[,'Segment'])
  
  tr = segmentCust %>%
    group_by(Segment, Gender) %>%
    tally()
  
  data = as.data.frame(tr)
  
  Seg_Gen = ggplot(data, aes(fill= Gender, y=n, x=Segment)) + geom_bar(position="dodge", stat="identity")
  Seg_Age = ggplot(segmentCust, aes(x=Segment, y=Age, fill = Segment)) + geom_boxplot() + theme(legend.position='none')
  Seg_AnnInc = ggplot(segmentCust, aes(x=Segment, y=AnnualIncome, fill = Segment)) + geom_boxplot() + theme(legend.position='none')
  Seg_SpeSco = ggplot(segmentCust, aes(x=Segment, y=SpendingScore, fill = Segment)) + geom_boxplot() + theme(legend.position='none')
  
  grid.arrange(Seg_Gen,Seg_Age, Seg_AnnInc, Seg_SpeSco, nrow = 2)
}

#############################################################
# Data preparation
#read data
custData = read.csv('Mall_Customers.csv', header = TRUE)
#rename badly named columns into right ones
colnames(custData)[4] = 'AnnualIncome'
colnames(custData)[5] = 'SpendingScore'

#check for missing values
if (sum(is.na(custData))){
  #remove missing values
  custData = custData[complete.cases(custData),] 
}
###############################################################

####DATA EXPLORATION

#pie chart that represents the number of male and female customers
gender_stat <- data.frame("Gender" = c("Male", "Female"), "Number" = c(sum(custData[,"Gender"] == 'Male'),sum(custData[,"Gender"] == 'Female')))

blank_theme <- theme_minimal()+
  theme(
    axis.title.x = element_blank(),
    axis.title.y = element_blank(),
    panel.border = element_blank(),
    panel.grid=element_blank(),
    axis.ticks = element_blank(),
    plot.title=element_text(size=14, face="bold")
  )


bp<- ggplot(gender_stat, aes(x="", y = Number, fill= Gender))+geom_bar(width = 1, stat = "identity")
pie <- bp + coord_polar("y", start=0)

Gender_Disrt = pie + blank_theme +
  theme(axis.text.x=element_blank()) +
  geom_text(aes(y = Number/2 + c(0, cumsum(Number)[-length(Number)]), 
                label = percent(Number/sum(Number))), size=5)+ ggtitle("Gender distribution") + theme(plot.title = element_text(hjust = 0.5, vjust = -4))



#pairwise plot that represents: 
# 1) pearson measure of correlation
# 2) histograms
# 3) scatter polots
pairs.panels(custData[,3:5], 
             method = "pearson", 
             hist.col = "#00AFBB",
             density = FALSE,
             ellipses = FALSE,
             smooth = FALSE
             
)

##box plots for gender
Gen_Age = ggplot(custData, aes(x=Gender, y=Age, fill=Gender)) + geom_boxplot() + theme(legend.position='none')
Gen_AnnInc = ggplot(custData, aes(x=Gender, y=AnnualIncome, fill=Gender)) + geom_boxplot() + theme(legend.position='none')
Gen_SpeSco = ggplot(custData, aes(x=Gender, y=SpendingScore, fill=Gender)) + geom_boxplot() + theme(legend.position='none')
grid.arrange(Gender_Disrt,Gen_Age, Gen_AnnInc, Gen_SpeSco, nrow = 2)

###############################################################################
###CLUSTERIZATION
#k-medoids (fast and simple algorithm)
#gower distance
gower_dist <- daisy(custData[,-1], metric = "gower")

#find sihouette width value
silh = data.frame(matrix(ncol = 10, nrow = 1))
for (i in 2:10){
  #run the sfkm algorihtm
  sfkm = fastkmed(gower_dist, ncluster = i)
  #calculate silhouette of the sfkm result
  siliris = sil(gower_dist, sfkm$medoid, sfkm$cluster)
  silh[,i] = mean(siliris$result[,1])
}
# Plot sihouette width (higher is better)
plot(main = "Silhouette width graph",
     seq(2,10), 
     silh[1,-1],
     type="b", 
     pch = 19, 
     frame = FALSE, 
     xlab="Number of clusters",
     xaxt = "n",
     ylab="Silhouette Width"
)
axis(1, at = seq(2,10))

#run the sfkm algorihtm
sfkmOpt <- fastkmed(gower_dist, ncluster = 4)

#plot characteristics of each segment
segmentCharacter(sfkmOpt$cluster)


#k-medoids
#find sihouette width value
silh = data.frame(matrix(ncol = 10, nrow = 1))
for (i in 2:10){
  #initial medoids' assignment
  set.seed(1)
  kminit <- sample(1:nrow(custData), i)
  #run the sfkm algorihtm
  sfkm = fastkmed(gower_dist, ncluster = i, init = kminit)
  #calculate silhouette of the sfkm result
  siliris = sil(gower_dist, sfkm$medoid, sfkm$cluster)
  silh[,i] = mean(siliris$result[,1])
}

# Plot sihouette width (higher is better)
plot(main = "Silhouette width graph",
     seq(2,10), 
     silh[1,-1],
     type="b", 
     pch = 19, 
     frame = FALSE, 
     xlab="Number of clusters",
     xaxt = "n",
     ylab="Silhouette Width"
)
axis(1, at = seq(2,10))

#run the k-medoids algorihtm
set.seed(1)
kminit <- sample(1:nrow(custData), 5)
kmOpt <- fastkmed(gower_dist, ncluster = 5, init = kminit)

#plot characteristics of each segment
segmentCharacter(kmOpt$cluster)


# k-prototypes 
es = numeric(10)
for(i in 1:10){
  kpres = kproto(x = custData[,-1], k = i, nstart = 5) 
  es[i] = kpres$tot.withinss
}
plot(1:10, es, type = "b", ylab = "Total within-clusters sum of squares", xlab = "Number of clusters K", main = "Elbow graph")
#run the k-prototypes algorihtm
kpres <- kproto(x = custData[,-1], k = 6)
segmentCharacter(kpres$cluster)