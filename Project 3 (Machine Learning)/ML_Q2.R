#import of all needed libraries
#check package for existence
#if the nedeed package does not exist -> install it and then import it
#if the nedeed package exists -> just import it

package_names = c('gdata','dplyr','smotefamily','caret',
                  'pROC', 'ROCR', 'ggplot2', 'Rmisc')

for (pac_name in package_names){
  installed_pack<-installed.packages()[,1]
  if(!is.element(pac_name, installed_pack)){
    install.packages(pac_name)
  }
  library(pac_name, character.only=TRUE)
}

RNGkind(sample.kind = "Rounding")

#functions
oversampling <- function(dataset){

  # separate minority and majority classes
  not_fraud = dataset[dataset$Class == 'legitimate',]
  fraud = dataset[dataset$Class == 'fraud',]
  
  #this is for reproducibility
  set.seed(10)
  # upsample minority
  fraud_upsampled = sample_n(fraud,
                             replace = TRUE, # sample with replacement
                             size = nrow(not_fraud))# match number in majority class

  # combine majority and upsampled minority
  upsampled = rbind(not_fraud, fraud_upsampled)
  
  #suffle balanced dataset
  
  #this is for reproducibility
  set.seed(12)
  upsampled = upsampled[sample(nrow(upsampled)),]
  
  return(upsampled)
}

undersampling <- function(dataset){

  # separate minority and majority classes
  not_fraud = dataset[dataset$Class == 'legitimate',]
  fraud = dataset[dataset$Class == 'fraud',]
  
  #this is for reproducibility
  set.seed(10)

  # downsample majority
  not_fraud_downsampled = sample_n(not_fraud,
                                   replace = FALSE, # sample without replacement
                                   size = nrow(fraud)) # match minority n
  
  
  # combine majority and upsampled minority
  downsampled = rbind(not_fraud_downsampled, fraud)
  
  #suffle balanced dataset
  
  #this is for reproducibility
  set.seed(12)
  downsampled = downsampled[sample(nrow(downsampled)),]
  
  return(downsampled)
}

smotesampling <- function(dataset){
  
  # separate minority and majority classes
  not_fraud = dataset[dataset$Class == 'legitimate',]
  fraud = dataset[dataset$Class == 'fraud',]
  
  n0 = nrow(not_fraud)
  n1 = nrow(fraud)
  
  #desired percenage of legitimate cases
  r0 = 0.5
  
  #value for the dup_size parameter of SMOTE
  ntimes = ((1 - r0) / r0) * (n0/ n1) - 1
  
  #this is for reproducibility
  set.seed(14)
  smote_output = SMOTE(X = dataset[, -31], target = dataset$Class, K = 5, dup_size = ntimes)
  
  #smote output
  credit_smote = smote_output$data
  
  colnames(credit_smote)[31] = 'Class'
  #transform Class variable again to factor variable 
  credit_smote[,'Class'] = as.factor(credit_smote[,'Class'])
  
  #suffle balanced dataset
  
  #this is for reproducibility
  set.seed(15)
  credit_smote = credit_smote[sample(nrow(credit_smote)),]
  
  return(credit_smote)
}

knnMethod <- function (training){
  fitControl = trainControl(
    method = "cv",
    number = 5,
    summaryFunction = twoClassSummary,
    classProbs = TRUE
  )
  set.seed(5)
  knnFit = train(training[,-31], training[,31], method = "knn", 
                 trControl = fitControl, metric = "ROC")
  knnProbs = predict(knnFit,newdata = test.sc[,-31], type = "prob")
  knnROC = roc(predictor = knnProbs$legitimate,
               response = test.sc[,31],
               levels=rev(levels(test.sc[,31])))
  #AUC values from knn
  return(knnROC$auc)
}

ldaMethod <- function (training){
  ldaFit = train(training[,-31], training[,31], method = "lda2",
                 trControl = trainControl(method = "none"))
  ldaProbs = predict(ldaFit,newdata = test[,-31],type="prob")
  ldaROC = roc(predictor = ldaProbs$legitimate,
               response = test.sc[,31],
               levels=rev(levels(test.sc[,31])))
  #AUC values from LDA
  return(ldaROC$auc)
}

logisticregMethod <- function (trainig, name){
  #for logistic regression response variables should be 0 and 1
  levels(trainig$Class) <- c(0, 1)
  testing = test
  levels(testing$Class) <- c(0, 1)
  logFit = glm(Class ~ .,data = trainig, family = binomial(link = 'logit'), maxit = 500)
  logProbs = predict(logFit, newdata = testing[,-31],type = "response")
  if(name == 'smote')
    pr = prediction(logProbs, testing[,31], label.ordering = c(1,0))
  else
    pr = prediction(logProbs, testing[,31], label.ordering = c(0,1))
  prf = performance(pr, measure = "tpr", x.measure = "fpr")
  auc = performance(pr, measure = "auc")
  return(auc@y.values[[1]])
}

dectreeMethod <- function(trainig){
  fitcontrol = trainControl(method = "repeatedcv",
                            number = 5,
                            repeats = 3,
                            summaryFunction = twoClassSummary,
                            classProbs = TRUE)
  set.seed(60)
  treeFit = train(trainig[,-31],
                  trainig[,31],
                  method = "rpart",
                  tuneLength = 6,
                  trControl = fitcontrol,
                  metric = "ROC")
  
  treeProbs = predict(treeFit, test[,-31], type = 'prob')
  
  treeROC = roc(predictor = treeProbs$legitimate,
                response = test[,31],
                levels=rev(levels(test[,31])))
  
  #AUC values from DT
  return(treeROC$auc)
}

rfMethod <- function(trainig){
  
  fitControl = trainControl(method = "cv",
                            number = 3,
                            summaryFunction = twoClassSummary,
                            classProbs = TRUE)
  set.seed(61)
  
  rfFit = train(trainig[,-31],
                trainig[,31],
                method = "rf",
                metric = "ROC",
                trControl = fitControl, 
                tuneLength = 4)
  
  rfProbs = predict(rfFit, test[,-31], type = 'prob')
  rfROC = roc(predictor = rfProbs$legitimate,
              response = test[,31],
              levels=rev(levels(test[,31])))
  
  #AUC values from RF
  return(rfROC$auc)
}

SVMMethod <- function(trainig, kernel){
  
  if(kernel == 'linear')
    method = 'svmLinear2'
  if(kernel == 'radial')
    method = 'svmRadial'
  
  fitControl = trainControl(method = "cv",
                            number = 4,
                            summaryFunction = twoClassSummary,
                            classProbs = TRUE)
  set.seed(61)
  
    
  svmFit =  train(trainig[,-31], 
                  trainig[,31],
                  method = method,
                  metric = "ROC",
                  trControl = fitControl,
                  tuneLength = 4)
  
  svmProbs = predict(svmFit, test.sc[,-31], type = 'prob')
  svmROC = roc(predictor = svmProbs$fraud,
               response = test.sc[,31],
               levels=rev(levels(test.sc[,31])))
  
  #AUC values from RF
  return(svmROC$auc)
}

samplingBoxPlot <- function(overSampl, underSampl, smoteSampl, initial, title){
  
  ylim = min(overSampl,underSampl,smoteSampl,initial) - 0.1
  
  oversampl = ggplot(data.frame(overSampl), aes(x = '', y = overSampl))+
    geom_boxplot() + theme(legend.position='none')+
    labs(y ='Accuracy')+
    labs(x = 'Oversampling')+
    coord_cartesian(ylim = c(ylim, 1))
  undersampl = ggplot(data.frame(underSampl), aes(x = '', y = underSampl))+ 
    geom_boxplot() + theme(legend.position='none')+ 
    labs(y ='Accuracy')+
    labs(x = 'Undersampling')+
    coord_cartesian(ylim = c(ylim, 1))
  smotesampl = ggplot(data.frame(smoteSampl), aes(x = '', y = smoteSampl))+
    geom_boxplot() + theme(legend.position='none')+ 
    labs(y ='Accuracy')+
    labs(x = 'SMOTEsampling')+
    coord_cartesian(ylim = c(ylim, 1))
  initsampl = ggplot(data.frame(initial), aes(x = '', y = initial))+
    geom_boxplot() + theme(legend.position='none')+ 
    labs(y ='Accuracy')+
    labs(x = 'Initial')+
    coord_cartesian(ylim = c(ylim, 1))
  grid.arrange(oversampl,undersampl, smotesampl,initsampl, top=paste("Accuracy Box Plot for",title), nrow = 1)
}

samplingBoxPlotSVM <- function(overSampl_lin,overSampl_rad, underSampl_lin, underSampl_rad, smoteSampl_lin, smoteSampl_rad, initial_lin, initial_rad){
  
  ylim = min(overSampl_lin,overSampl_rad,underSampl_lin,underSampl_rad,smoteSampl_lin,smoteSampl_rad,initial_lin, initial_rad) - 0.1
  
  oversampl_lin = ggplot(data.frame(overSampl_lin), aes(x = '', y = overSampl_lin))+
    geom_boxplot() + theme(legend.position='none')+
    labs(y ='Accuracy')+
    labs(x = 'Oversampling_lin')+
    coord_cartesian(ylim = c(ylim, 1))
  oversampl_rad = ggplot(data.frame(overSampl_rad), aes(x = '', y = overSampl_rad))+
    geom_boxplot() + theme(legend.position='none')+
    labs(y ='Accuracy')+
    labs(x = 'Oversampling_rad')+
    coord_cartesian(ylim = c(ylim, 1))
  undersampl_lin = ggplot(data.frame(underSampl_lin), aes(x = '', y = underSampl_lin))+ 
    geom_boxplot() + theme(legend.position='none')+ 
    labs(y ='Accuracy')+
    labs(x = 'Undersampling_lin')+
    coord_cartesian(ylim = c(ylim, 1))
  undersampl_rad = ggplot(data.frame(underSampl_rad), aes(x = '', y = underSampl_rad))+ 
    geom_boxplot() + theme(legend.position='none')+ 
    labs(y ='Accuracy')+
    labs(x = 'Undersampling_rad')+
    coord_cartesian(ylim = c(ylim, 1))
  smotesampl_lin = ggplot(data.frame(smoteSampl_lin), aes(x = '', y = smoteSampl_lin))+
    geom_boxplot() + theme(legend.position='none')+ 
    labs(y ='Accuracy')+
    labs(x = 'SMOTEsampling_lin')+
    coord_cartesian(ylim = c(ylim, 1))
  smotesampl_rad = ggplot(data.frame(smoteSampl_rad), aes(x = '', y = smoteSampl_rad))+
    geom_boxplot() + theme(legend.position='none')+ 
    labs(y ='Accuracy')+
    labs(x = 'SMOTEsampling_rad')+
    coord_cartesian(ylim = c(ylim, 1))
  initsampl_lin = ggplot(data.frame(initial_lin), aes(x = '', y = initial_lin))+
    geom_boxplot() + theme(legend.position='none')+ 
    labs(y ='Accuracy')+
    labs(x = 'Initial_lin')+
    coord_cartesian(ylim = c(ylim, 1))
  initsampl_rad = ggplot(data.frame(initial_rad), aes(x = '', y = initial_rad))+
    geom_boxplot() + theme(legend.position='none')+ 
    labs(y ='Accuracy')+
    labs(x = 'Initial_lin')+
    coord_cartesian(ylim = c(ylim, 1))
  grid.arrange(oversampl_lin,oversampl_rad, undersampl_lin,undersampl_rad,smotesampl_lin,smotesampl_rad,initsampl_lin,initsampl_rad,top=paste("Accuracy Box Plot for SVM"), nrow = 2)
}

accuracyBoxPlot <- function(knn, lda, logist, dt, rf, svm){
  
  ylim = min(knn, lda, logist, dt, rf, svm) - 0.1
  
  knnPl = ggplot(data.frame(knn), aes(x = '', y = knn))+
    geom_boxplot() + theme(legend.position='none')+
    labs(y ='Accuracy')+
    labs(x = 'KNN')+
    coord_cartesian(ylim = c(ylim, 1))
  ldaPl = ggplot(data.frame(lda), aes(x = '', y = lda))+ 
    geom_boxplot() + theme(legend.position='none')+ 
    labs(y ='Accuracy')+
    labs(x = 'LDA')+
    coord_cartesian(ylim = c(ylim, 1))
  logPl = ggplot(data.frame(logist), aes(x = '', y = logist))+
    geom_boxplot() + theme(legend.position='none')+ 
    labs(y ='Accuracy')+
    labs(x = 'Logistic')+
    coord_cartesian(ylim = c(ylim, 1))
  dtPl = ggplot(data.frame(dt), aes(x = '', y = dt))+
    geom_boxplot() + theme(legend.position='none')+ 
    labs(y ='Accuracy')+
    labs(x = 'DT')+
    coord_cartesian(ylim = c(ylim, 1))
  rfPl = ggplot(data.frame(rf), aes(x = '', y = rf))+
    geom_boxplot() + theme(legend.position='none')+ 
    labs(y ='Accuracy')+
    labs(x = 'RF')+
    coord_cartesian(ylim = c(ylim, 1))
  svmPl = ggplot(data.frame(svm), aes(x = '', y = svm))+
    geom_boxplot() + theme(legend.position='none')+ 
    labs(y ='Accuracy')+
    labs(x = 'SVM')+
    coord_cartesian(ylim = c(ylim, 1))
  grid.arrange(knnPl,ldaPl, logPl,dtPl,rfPl,svmPl, top="Accuracy Box Plot for comparison", nrow = 1)
}
#############################################################
# Data preparation
#read data
creditFraud = read.csv('credit_fraud.csv', header = TRUE)

#check for missing values
if (sum(is.na(creditFraud))){
  #remove missing values
  creditFraud = creditFraud[complete.cases(creditFraud),] 
}

#make 'class' variable factor variable
creditFraud[,'Class'] = as.factor(creditFraud[,'Class'])

#levels should be named (not 0 and 1)
levels(creditFraud$Class) <- c("legitimate", "fraud")
###############################################################
#DATA EXPLORATION
#number of fraudulent and non fraudulent transactions
table(creditFraud[,'Class'])
## Plot Pie chart for fraud and non-fraud Distribution
fraud_stat <- data.frame("Class" = c("fraud", "not fraud"), 
                         "Number" = c(sum(creditFraud[,"Class"] == "legitimate"),
                                      sum(creditFraud[,"Class"] == "fraud")))
bp<- ggplot(fraud_stat, aes(x="", y = Number, fill= Class))+geom_bar(width = 1, stat = "identity")
pie <- bp + coord_polar("y", start=0)

blank_theme <- theme_minimal()+
  theme(
    axis.title.x = element_blank(),
    axis.title.y = element_blank(),
    panel.border = element_blank(),
    panel.grid=element_blank(),
    axis.ticks = element_blank(),
    plot.title=element_text(size=14, face="bold")
  )

fraud_Disrt = pie + blank_theme +
  theme(axis.text.x=element_blank()) +
  geom_text(aes(y = Number/2 + c(0, cumsum(Number)[-length(Number)]), 
                label = percent(Number/sum(Number))), size=5)+ 
  ggtitle("Fraud Data Distribution") + 
  theme(plot.title = element_text(hjust = 0.5, vjust = -4))

##Plot Histogram for time features 
creditFraud[,'Class'] = as.factor(creditFraud[,'Class'])
time_His = ggplot(creditFraud, aes(x=Time, fill=Class)) +
  geom_histogram(breaks = seq(0, 172800, 3600),  binwidth=1, alpha=.8,
                 position="identity") +
  ggtitle("Distibution of Time") +
  theme(plot.title = element_text(hjust = 0.5))

##Plot Histogram for amount distribution
amount_His = ggplot(creditFraud, aes(x=Amount, fill=Class)) + 
  geom_histogram(breaks = seq(0, 5300, 100), binwidth=1, alpha=.8) +
  ggtitle("Distibution of Amount") +
  theme(plot.title = element_text(hjust = 0.5))
grid.arrange(fraud_Disrt, time_His, amount_His )

## Correlations plots 
corr_plots <- list()  # new empty list
for (i in 1:30) {
  if (i != 30){
    p1 <- eval(substitute(
      ggplot(creditFraud, aes(x=creditFraud[,i], fill=Class))+ 
        geom_density(alpha=.2,)+
        labs(x=colnames(creditFraud[i]))+
        theme(legend.position = "none")
      ,list(i = i)))
    corr_plots[[i]] <- p1  # add each plot into plot list
  }else{
    p1 <- eval(substitute(
      ggplot(creditFraud, aes(x=creditFraud[,i], fill=Class))+ 
        geom_density(alpha=.2,)+
        labs(x=colnames(creditFraud[i]))
      ,list(i = i)))
    corr_plots[[i]] <- p1  # add each plot into plot list
  }
}
multiplot(plotlist = corr_plots, cols = 6)

###############################################################
#CLASSIFICATION METHODS

#PREPARATION
#some classification methods need scaled data and some classification methods don't
#thefore 'Time' and 'Amount' will be  scaled

#scaled dataset
creditFraud.sc = cbind(scale(creditFraud[,c(1,30)]),creditFraud[,c(2:29,31)])

#randomly split the whole dataset into trainig and test sets (70%/30%)
#seed is for reproducibility
set.seed(10)

A = 10
trainIndex = createDataPartition(creditFraud[,ncol(creditFraud)],p = 0.7,list = FALSE, times = A)

#vectors for 10AUC values of kNN (different sampling techniques)
AUCkNN_oversampl = vector("numeric", A)
AUCkNN_undersampl = vector("numeric", A)
AUCkNN_smotesampl = vector("numeric", A)
AUCkNN_initsampl = vector("numeric", A)

#vectors for 10AUC values of kNN (different sampling techniques)
AUCLDA_oversampl = vector("numeric", A)
AUCLDA_undersampl = vector("numeric", A)
AUCLDA_smotesampl = vector("numeric", A)
AUCLDA_initsampl = vector("numeric", A)

#vectors for 10AUC values of logistic regression (different sampling techniques)
logistic_oversampl = vector("numeric", A)
logistic_undersampl = vector("numeric", A)
logistic_smotesampl = vector("numeric", A)
logistic_initsampl = vector("numeric", A)

#vectors for 10AUC values of decision tree (different sampling techniques)
dt_oversampl = vector("numeric", A)
dt_undersampl = vector("numeric", A)
dt_smotesampl = vector("numeric", A)
dt_initsampl = vector("numeric", A)

#vectors for 10AUC values of random forest (different sampling techniques)
rf_oversampl = vector("numeric", A)
rf_undersampl = vector("numeric", A)
rf_smotesampl = vector("numeric", A)
rf_initsampl = vector("numeric", A)

#vectors for 10AUC values of SVM (different sampling techniques and different kernels)
SVMlin_oversampl = vector("numeric", A)
SVMrad_oversampl = vector("numeric", A)
SVMlin_undersampl = vector("numeric", A)
SVMrad_undersampl = vector("numeric", A)
SVMlin_smotesampl = vector("numeric", A)
SVMrad_smotesampl = vector("numeric", A)
SVMlin_initsampl = vector("numeric", A)
SVMrad_initsampl = vector("numeric", A)

#cycle for each random split
for (ii in 1:A){
  
  #training sets (scaled and original)
  train = creditFraud[trainIndex[,ii],]
  train.sc = creditFraud.sc[trainIndex[,ii],]
  #test sets (scaled and original)
  test = creditFraud[-trainIndex[,ii],]
  test.sc = creditFraud.sc[-trainIndex[,ii],]
  
  
  #since the initial (scaled) dataset is imbalanced
  #then before performing classification methods
  #train dataset should become balanced
  #there are 3 ways of doing this: under-sample, over-sample and SMOTE
  
  train_oversampled = oversampling(train)
  train_undersampled = undersampling(train)
  train_smote = smotesampling(train)
  
  
  train.sc_oversampled = oversampling(train.sc)
  train.sc_undersampled = undersampling(train.sc)
  train.sc_smote = smotesampling(train.sc)

  #knn accuracies for different sampling techniques
  AUCkNN_oversampl[ii] = knnMethod(train.sc_oversampled)
  AUCkNN_undersampl[ii] = knnMethod(train.sc_undersampled)
  AUCkNN_smotesampl[ii] = knnMethod(train.sc_smote)
  AUCkNN_initsampl[ii] = knnMethod(train.sc)
  
  #LDA accuracies for different sampling techniques
  AUCLDA_oversampl[ii] = ldaMethod(train_oversampled)
  AUCLDA_undersampl[ii] = ldaMethod(train_undersampled)
  AUCLDA_smotesampl[ii] =ldaMethod(train_smote)
  AUCLDA_initsampl[ii] =ldaMethod(train)
  
  #logistic regression for different sampling techniques
  logistic_oversampl[ii] = logisticregMethod(train_oversampled,'oversampled')
  logistic_undersampl[ii] = logisticregMethod(train_undersampled, 'undersampled')
  logistic_smotesampl[ii] = logisticregMethod(train_smote, 'smote')
  logistic_initsampl[ii] = logisticregMethod(train,'')

  #compare sampling techniques for decision tree
  dt_oversampl[ii] = dectreeMethod(train_oversampled)
  dt_undersampl[ii] = dectreeMethod(train_undersampled)
  dt_smotesampl[ii] = dectreeMethod(train_smote)
  dt_initsampl[ii] = dectreeMethod(train)
  
  #compare sampling techniques for random forest
  rf_oversampl[ii] = rfMethod(train_oversampled)
  rf_undersampl[ii] = rfMethod(train_undersampled)
  rf_smotesampl[ii] = rfMethod(train_smote)
  rf_initsampl[ii] = rfMethod(train)
  
  #compare sampling techniques(and different kernels) for SVM
  SVMlin_oversampl[ii] = SVMMethod(train.sc_oversampled, 'linear')
  SVMrad_oversampl[ii] = SVMMethod(train.sc_oversampled, 'radial')
  SVMlin_undersampl[ii] = SVMMethod(train.sc_undersampled, 'linear')
  SVMrad_undersampl[ii] = SVMMethod(train.sc_undersampled, 'radial')
  SVMlin_smotesampl[ii] = SVMMethod(train.sc_smote, 'linear')
  SVMrad_smotesampl[ii] = SVMMethod(train.sc_smote, 'radial')
  SVMlin_initsampl[ii] = SVMMethod(train.sc, 'linear')
  SVMrad_initsampl[ii] = SVMMethod(train.sc, 'radial')
  
}

samplingBoxPlot(AUCkNN_oversampl,AUCkNN_undersampl,AUCkNN_smotesampl,AUCkNN_initsampl, "kNN")
samplingBoxPlot(AUCLDA_oversampl,AUCLDA_undersampl,AUCLDA_smotesampl,AUCLDA_initsampl, "LDA")
samplingBoxPlot(logistic_oversampl,logistic_undersampl,logistic_smotesampl,logistic_initsampl, "Logistic")
samplingBoxPlot(dt_oversampl,dt_undersampl,dt_smotesampl,dt_initsampl,"Decision Tree")
samplingBoxPlot(rf_oversampl,rf_undersampl,rf_smotesampl,rf_initsampl,"Random Forest")
samplingBoxPlotSVM(SVMlin_oversampl,SVMrad_oversampl,SVMlin_undersampl,SVMrad_undersampl,SVMlin_smotesampl,SVMrad_smotesampl,SVMlin_initsampl,SVMrad_initsampl)

accuracyBoxPlot(AUCkNN_undersampl,AUCLDA_oversampl,logistic_smotesampl,dt_smotesampl,rf_smotesampl,SVMrad_oversampl)


