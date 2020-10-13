#import needed libraries
library(nloptr)
library(RColorBrewer)

####################################################################
#functions
####################################################################

#traditional dynamic programming with mixed arrivals and discrete time
dynamicTraditional <- function(capacity){
  
  #initialization
  C = capacity
  #value matrix
  vTraditional = matrix(rep(0, len = (C + 1) * (TT + 1)), nrow = C + 1)
  #decision about low fare
  acceptLowTraditional = matrix(rep(0, len = (C + 1) * (TT + 1)), nrow = C + 1)
  #decision about medium fare
  acceptMedTraditional = matrix(rep(0, len = (C + 1) * (TT + 1)), nrow = C + 1)
  
  # Terminal Values
  for(i in 1:(C+1)){
    vTraditional[i,1] = 0
  }
  
  # Dynamic Programming Recursion
  for(t in 2:(TT+1)){ 
    for(i in 1:(C+1)){ 
      
      # For no arrivals:
      vtogo0 = vTraditional[i,t-1]
      
      # For low fare clients arrival:
      vtogoLow = vTraditional[i,t-1]
      #decision for low fare (accept/reject)
      acceptLowTraditional[i,t] = 0
      # If resource available:
      if(i>1){
        vtogoLow = max(priceLow + vTraditional[i-1,t-1], vTraditional[i,t-1])
        # Recording the decision:
        if(priceLow + vTraditional[i-1,t-1]>vTraditional[i,t-1]){
          acceptLowTraditional[i,t] = 1
        }
      }
      
      # For Medium fare clients arrival:
      vtogoMed = vTraditional[i,t-1]
      #decision for medium fare (accept/reject)
      acceptMedTraditional[i,t] = 0
      # If resource available:
      if(i>1){
        vtogoMed = max(priceMed + vTraditional[i-1,t-1], vTraditional[i,t-1])
        # Recording the decision:
        if(priceMed + vTraditional[i-1,t-1] > vTraditional[i,t-1]){
          acceptMedTraditional[i,t] = 1
        }
      }
      
      # For high fare clients arrival (those are always accepted):
      vtogoHigh = vTraditional[i,t-1] # default
      # If resource available:
      if(i>1){
        vtogoHigh = priceHigh + vTraditional[i-1,t-1]
      }
      
      # expected revenue
      vTraditional[i,t] = lambda0 * vtogo0 + lambda1 * vtogoLow + lambda2 * vtogoMed + lambda3 * vtogoHigh
    } 
  }
  OptimalRevenueTraditional = vTraditional[(C+1),(TT+1)]
  returnList = list(revenue = OptimalRevenueTraditional, accLow = acceptLowTraditional,accMed = acceptMedTraditional)
  
  return (returnList)
}

#enhanced dynamic programming strategy that considers buy-up(down) behavior
dynamicEnhanced <- function(capacity){
  C = capacity
  #value matrix
  vEnhanced = matrix(rep(0, len = (C + 1) * (TT + 1)), nrow = C + 1)
  
  #decision about low fare
  acceptLowEnhanced = matrix(rep(0, len = (C + 1) * (TT + 1)), nrow = C + 1)
  #decision about medium fare
  acceptMedEnhanced = matrix(rep(0, len = (C + 1) * (TT + 1)), nrow = C + 1)
  
  #decision after initial request was rejected
  acceptMed_Lowrej = matrix(rep(0, len = (C + 1) * (TT + 1)), nrow = C + 1)
  acceptLow_Medrej = matrix(rep(0, len = (C + 1) * (TT + 1)), nrow = C + 1)
  
  # Terminal Values
  for(i in 1:(C+1)){
    vEnhanced[i,1] = 0
  }
  
  # Dynamic Programming Recursion
  for(t in 2:(TT+1)){ 
    for(i in 1:(C+1)){
      # For no arrivals:
      vtogo0 = vEnhanced[i,t-1]
      
      # For low fare clients arrival:
      vtogoLow = vEnhanced[i,t-1]
      #decision for low fare (accept/reject)
      acceptLowEnhanced[i,t] = 0
      # If resource available:
      if(i>1){
        acceptRevenue = priceLow + vEnhanced[i-1,t-1]
        rejectRevenue = qLow_Med * max(priceMed + vEnhanced[i-1,t-1], vEnhanced[i,t-1]) + qLow_High * (priceHigh + vEnhanced[i-1,t-1]) + qLow_No * vEnhanced[i,t-1]
        vtogoLow = max(acceptRevenue, rejectRevenue)
        # Recording the decision:
        if(acceptRevenue > rejectRevenue){
          acceptLowEnhanced[i,t] = 1
        }else{
          #this is for the first rejection
          #after first rejection, low fare client can request for medium fare, high fare or just leave
          #medium fare request can be rejected or accepted
          #high fare will always be accepted
          acceptMed_Lowrej[i,t] = 0
          acceptMedium = priceMed + vEnhanced[i-1,t-1]
          rejectMedium = vEnhanced[i,t-1]
          #if there will be a request for medium fare and the revenue of acceptance will be higher than rejection -> accept
          if(acceptMedium > rejectMedium){
            acceptMed_Lowrej[i,t] = 1
          }
        }
      }
      
      # For low fare clients arrival:
      vtogoMed = vEnhanced[i,t-1]
      #decision for medium fare (accept/reject)
      acceptMedEnhanced[i,t] = 0
      # If resource available:
      if(i>1){
        acceptRevenue = priceMed + vEnhanced[i-1,t-1]
        rejectRevenue = qMed_Low * max(priceLow + vEnhanced[i-1,t-1], vEnhanced[i,t-1]) + qMed_High * (priceHigh + vEnhanced[i-1,t-1]) + qMed_No * vEnhanced[i,t-1]
        vtogoMed = max(acceptRevenue, rejectRevenue)
        # Recording the decision:
        if(acceptRevenue > rejectRevenue){
          acceptMedEnhanced[i,t] = 1
        }else{
          #this is for the first rejection
          #after first rejection, medium fare client can request for low fare, high fare or just leave
          #low fare request can be rejected or accepted
          #high fare will always be accepted
          acceptLow_Medrej[i,t] = 0
          acceptLow = priceLow + vEnhanced[i-1,t-1]
          rejectLow = vEnhanced[i,t-1]
          #if there will be a request for medium fare and the revenue of acceptance will be higher than rejection -> accept
          if(acceptLow > rejectLow){
            acceptLow_Medrej[i,t] = 1
          }
        }
      }
      
      # For high fare clients arrival (those are always accepted):
      vtogoHigh = vEnhanced[i,t-1] # default
      # If resource available:
      if(i>1){
        vtogoHigh = priceHigh + vEnhanced[i-1,t-1]
      }
      
      # expected revenue
      vEnhanced[i,t] = lambda0 * vtogo0 + lambda1 * vtogoLow + lambda2 * vtogoMed + lambda3 * vtogoHigh
    } 
  }
  
  OptimalRevenueEnhanced = vEnhanced[(C+1),(TT+1)]
  returnList = list(revenue = OptimalRevenueEnhanced,accLow = acceptLowEnhanced,accMed = acceptMedEnhanced)
  return(returnList)
}

#static overbooking strategy that considers cancellations and no-shows
overbooking <- function(b){
  #this is maximum expected revenue that could be obtained if everyone arrives and there are no cancellations
  maxExpectRevenue = p1*b*priceLow + p2*b*priceMed + p3*b*priceHigh
  #this is a refund in case of cancellation
  refund = alpha1*priceLow*p1*betta1c*b + alpha2*priceMed*p2*betta2c*b + alpha3*priceHigh*p3*betta3c*b
  #probability of showing up in one of the classes = sum of probabilities of show up in each class
  #this is total penalty in case of bumped clients
  pr = p1*betta1s + p2*betta2s + p3*betta3s
  #this cycle is for expected number of bumped customers
  bumpedClients = 0
  for (i in 1:b){
    bumpedClients = bumpedClients + dbinom(i,b,pr)*max(i-C,0)
  }
  #the total amount of penalty cost
  penalty = theta*bumpedClients
  #expected revenue
  expectRevenue = maxExpectRevenue - refund - penalty
  objfunction = expectRevenue
  return(objfunction)
}

####################################################################
#initialization of variables
####################################################################
#capacity
C = 230
#time horizon
TT = 400

#prices
priceLow = 16.99
priceMed = 56.99
priceHigh = 78.24

#request probabilities for each product
lambda0 = 0.1
lambda1 = 0.5
lambda2 = 0.3
lambda3 = 0.1

#buy-up probabilities after low-fare initial rejection
qLow_Med = 0.3
qLow_High = 0.1
qLow_No = 0.6

#buy-up and buy-down probabilities after medium-fare initial rejection
qMed_High = 0.4
qMed_Low = 0.2
qMed_No = 0.4

#From the arrival probabilities information(lambdas), the mean demand for each fare class can be found:
#E[D1] = 5/10 * 400 = 200
#E[D2] = 3/10 * 400 = 120
#E[D3] = 1/10 * 400 = 40
#total average number of people is E[D1]+E[D2]+E[D3] = 360
#from this, the probabilities of belonging to each class fare can be found
p1 = 200/360
p2 = 120/360
p3 = 40/360

#% for refund
alpha1 = 0.2
alpha2 = 0.3
alpha3 = 0.5

#probabilities of show-up according to the class
betta1s = 0.8
betta2s = 0.85
betta3s = 0.9

#probabilities of cancellation among no shows
sigma1 = 0.1
sigma2 = 0.15
sigma3 = 0.2

#probabilities of cancellation according to the class
betta1c = sigma1*(1-betta1s)
betta2c = sigma2*(1-betta2s)
betta3c = sigma3*(1-betta3s)

#penalty
theta = 160

#possible new capacities (considering overbooking)
possible_b = seq(231,280)


####################################################################
#Calculation
####################################################################

#initial capacity

OptimalRevenueTraditional = dynamicTraditional(C)$revenue
acceptedLowFareTraditional = dynamicTraditional(C)$accLow
acceptedMedFareTraditional = dynamicTraditional(C)$accMed
OptimalRevenueEnhanced = dynamicEnhanced(C)$revenue
acceptedLowFareEnchanced = dynamicEnhanced(C)$accLow
acceptedMedFareEnchanced = dynamicEnhanced(C)$accMed


#find new capacity
revenues = sapply(possible_b, FUN = overbooking)
newCapacity = possible_b[which(revenues == max(revenues))]

#new capacity
OptimalRevenueTraditionalOverbooking = dynamicTraditional(newCapacity)$revenue
acceptedLowFareTraditionalOverbooking = dynamicTraditional(newCapacity)$accLow
acceptedMedFareTraditionalOverbooking = dynamicTraditional(newCapacity)$accMed
OptimalRevenueEnhancedOverbooking = dynamicEnhanced(newCapacity)$revenue
acceptedLowFareEnchancedOverbooking = dynamicEnhanced(newCapacity)$accLow
acceptedMedFareEnchancedOverbooking = dynamicEnhanced(newCapacity)$accMed

#no low fares
sum(acceptedLowFareEnchancedOverbooking)

OptimalRevenueTraditional
OptimalRevenueTraditionalOverbooking
OptimalRevenueEnhancedOverbooking

#Visualize optimal policy structure
xaxis <- 1:TT
yaxis1 <- 1:C
yaxis2 <- 1:newCapacity
#Low-fare Class in Traditional Dynamic Model
acceptance1 <- t(acceptedLowFareTraditional[2:231,2:401])
filled.contour(xaxis, yaxis1, acceptance1, xaxt="n", yaxt="n",
               main = "Low Class in Traditional Dynamic Model",
               key.axes =  axis(4, seq(0, 1, by = 1)), nlevels = 2,
               col=brewer.pal(6,"PRGn"),
               xlab="Remaining Time", ylab="Remaining Number of Seats")
#Medium-fare Class in Traditional Dynamic Model
acceptance2 <- t(acceptedMedFareTraditional[2:231,2:401])
filled.contour(xaxis, yaxis1, acceptance2, xaxt="n", yaxt="n",
               main = "Medium Class in Traditional Dynamic Model",
               key.axes =  axis(4, seq(0, 1, by = 1)), nlevels = 2,
               col=brewer.pal(6,"PRGn"),
               xlab="Remaining Time", ylab="Remaining Number of Seats")
#Low-fare Class in Traditional Dynamic Model with Overbooking
acceptance3 <- t(acceptedLowFareTraditionalOverbooking[2:274,2:401])
filled.contour(xaxis, yaxis2, acceptance3, xaxt="n", yaxt="n",
               main = "Low Class in Overbooking Dynamic Model",
               key.axes =  axis(4, seq(0, 1, by = 1)), nlevels = 2,
               col=brewer.pal(6,"PRGn"),
               xlab="Remaining Time", ylab="Remaining Number of Seats")
#Medium-fare Class in Traditional Dynamic Model with Overbooking
acceptance4 <- t(acceptedMedFareTraditionalOverbooking[2:274,2:401])
filled.contour(xaxis, yaxis2, acceptance4, xaxt="n", yaxt="n",
               main = "Medium Class in Overbooking Dynamic Model",
               key.axes =  axis(4, seq(0, 1, by = 1)), nlevels = 2,
               col=brewer.pal(6,"PRGn"),
               xlab="Remaining Time", ylab="Remaining Number of Seats")
#Medium-fare Class in Enhanced Dynamic Model with Overbooking
acceptance5 <- t(acceptedMedFareEnchancedOverbooking[2:274,2:401])
filled.contour(xaxis, yaxis2, acceptance5, xaxt="n", yaxt="n",
               main = "Medium Class in Overbooking Enhanced Dynamic Model",
               key.axes =  axis(4, seq(0, 1, by = 1)), nlevels = 2,
               col=brewer.pal(6,"PRGn"),
               xlab="Remaining Time", ylab="Remaining Number of Seats")
