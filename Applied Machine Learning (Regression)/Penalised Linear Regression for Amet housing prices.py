
# coding: utf-8

# In[1]:


def fn_ames_en(df_all):
    
    import re
    import numpy as np
    import pandas as pd
    import pickle
    
    from sklearn.linear_model import ElasticNetCV, ElasticNet
    
    import matplotlib.pyplot as plt

    def convert(name):
        s1 = re.sub('\.', '_', name)
        return s1.lower()

    def fn_MAE(actuals, predictions):
        return np.round(np.mean(np.abs(predictions - actuals)), 0)

    def fn_tosplines(x):
        x = x.values
        #remove zeros to avoid issues where lots of values are zero
        x_nonzero = x[x != 0]
        ptiles = np.percentile(x_nonzero, [20, 50, 80])
        #print(var, ptiles)
        df_ptiles = pd.DataFrame({var: x})
        for idx, ptile in enumerate(ptiles):
            df_ptiles[var + '_' + str(idx)] = np.maximum(0, x - ptiles[idx])
        return(df_ptiles)

    
    # change column names to closer to camel case
    colnames = df_all.columns.values
    colnames = list(map(convert, colnames))
    df_all.columns = colnames
    del convert, colnames
    
    # define variables
    vars_all = df_all.columns.values
    var_dep = ['saleprice']
    
    vars_notToUse = ['order', 'pid']
    vars_ind = [var for var in vars_all if var not in (vars_notToUse + var_dep)]
    vars_ind_numeric = list(df_all[vars_ind].columns[df_all[vars_ind].dtypes != 'object'])
    
    # Deal with missings
    vars_toDrop = ['lot_frontage', 'garage_yr_blt', 'mas_vnr_area']
    df_all.drop(labels=vars_toDrop,
                axis=1,
                inplace=True)
    
    vars_ind = [var for var in vars_ind if var not in vars_toDrop]
    vars_ind_numeric = [var for var in vars_ind_numeric if var not in vars_toDrop]
    df_all.dropna(inplace = True)
    
    # remove outliers
    df_all = df_all[df_all['gr_liv_area'] <= 4000]
    df_all.reset_index(drop=True, inplace=True)
    
    # create onehot columns
    vars_ind_categorical = df_all.columns[df_all.dtypes == 'object'].tolist()
    vars_ind_onehot = []
    
    df_all_onehot = df_all.copy()
    
    for col in vars_ind_categorical:   
        # use pd.get_dummies on  df_all[col]
        df_oh = pd.get_dummies(df_all[col], drop_first=False) 
        # Find the name of the most frequent column
        col_mostFreq = df_oh.sum(axis = 0).idxmax()
        # Drop the column of the most frequent category (using df_oh.drop)
        df_oh = df_oh.drop(col_mostFreq, axis=1)
        # Rename the columns to have the original variable name as a prefix
        oh_names = col + '_' + df_oh.columns
        df_oh.columns = oh_names
        df_all_onehot = pd.concat([df_all_onehot, df_oh], axis = 1, sort = False)
        del df_all_onehot[col]
        vars_ind_onehot.extend(oh_names)
        
    # create fold
    rng = np.random.RandomState(2018)
    fold = rng.randint(0, 10, df_all.shape[0])
    df_all_onehot['fold'] = fold
        
    # rename df_all_onehot to df_all as this is now the data we will be using for
    # the rest of this work
    df_all = df_all_onehot
    del df_all_onehot
        
    # define index for train, val, design, test
    idx_train  = np.where(df_all['fold'].isin(np.arange(0,6)))[0]
    idx_val    = np.where(df_all['fold'].isin([6,7]))[0]
    idx_design = np.where(df_all['fold'].isin(np.arange(0,8)))[0]
    idx_test   = np.where(df_all['fold'].isin([8,9]))[0]
   
    # standardise features
    for var in vars_ind_numeric:
        x = df_all[var].values
        x -= np.mean(x, axis=0)
        x /= np.sqrt(np.mean(x ** 2, axis=0))
        df_all[var] = x
            
    vars_ind_tospline = df_all[vars_ind_numeric].columns[(df_all[vars_ind_numeric].nunique() > 3)].tolist()
            
    for var in vars_ind_tospline:
        df_ptiles = fn_tosplines(df_all[var])
        df_all.drop(columns=[var], inplace=True)
        vars_ind_numeric.remove(var)
        df_all = pd.concat([df_all, df_ptiles], axis=1, sort=False)
        vars_ind_numeric.extend(df_ptiles.columns.tolist())
                
    vars_ind = vars_ind_onehot + vars_ind_numeric
                
    X = df_all[vars_ind].values
    y = df_all[var_dep].values
                
    X_design = X[idx_design, :]
    X_test   = X[idx_test, :]
    y_design = df_all[var_dep].iloc[idx_design].copy().values.ravel()
    y_test   = df_all[var_dep].iloc[idx_test].copy().values.ravel()
                
    X = df_all[vars_ind].values
    y = df_all[var_dep].values
                
    X_train  = X[idx_train, :]
    X_val    = X[idx_val, :]
    X_design = X[idx_design, :]
    X_test   = X[idx_test, :]
                
    y_train  = df_all[var_dep].iloc[idx_train].copy().values.ravel()
    y_val    = df_all[var_dep].iloc[idx_val].copy().values.ravel()
    y_design = df_all[var_dep].iloc[idx_design].copy().values.ravel()
    y_test   = df_all[var_dep].iloc[idx_test].copy().values.ravel()
                
    enCV_ = ElasticNetCV(
        l1_ratio=0.83
    
        ,alphas=[2**num for num in range(-6,5)]
        ,max_iter=5000
        ,normalize=False
        ,cv=10
        ,random_state=2018
        ,selection='random'
        )

    enCV_.fit(X=X_design, y=y_design)

        

    en_ = ElasticNet(alpha=0.063
                     ,l1_ratio=0.83
                 
                     ,normalize=False
                     ,random_state=2018
                     ,selection='random'
                     ,max_iter=5000
                     )

    en_.fit(X=X_design, y=y_design)

    pred_design = en_.predict(X_design)
    pred_test   = en_.predict(X_test)
                
    
    mae_design = fn_MAE(y_design, pred_design)
    mae_test = fn_MAE(y_test,   pred_test)
                
    return [en_, X, y, 12608, 13592]

