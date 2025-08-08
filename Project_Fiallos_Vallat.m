%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Macroeconomics  II
% Empirical analysis of Costa Rica and Denmark
% Authors: Andrés Fiallos and Mathilde Vallat

% All data was extracted from OECD sources and INEC. Links in references in pdf report. 
% Code is available in the .qmd file in the folder

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 4);

% Specify range and delimiter
opts.DataLines = [2, Inf];
opts.Delimiter = ",";

% Specify column names and types
opts.VariableNames = ["REF_AREA", "TIME_PERIOD", "OBS_VALUE", "category"];
opts.VariableTypes = ["categorical", "string", "double", "categorical"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, "TIME_PERIOD", "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["REF_AREA", "TIME_PERIOD", "category"], "EmptyFieldRule", "auto");

% Import the data
DNKCRImacro = readtable("DNK_CRI_1990.csv", opts);

%% Clear temporary variables
clear opts

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Use HPFILTER to detrend and get the cycle of the relevant series
data = DNKCRImacro;

% Convert TIME_PERIOD to datetime with specified format
data.TIME_PERIOD = datetime(data.TIME_PERIOD, 'InputFormat', 'yyyy''-Q''Q', 'Format', 'yyyy-QQ');

% Sort data by TIME_PERIOD
data = sortrows(data, 'TIME_PERIOD');

% Initialize results table
hp_results = table();

% Loop over countries and variables
countries = unique(data.REF_AREA);

for n = 1:length(countries)
    country = countries(n);  % Extract country as a string
    
    % Filter by country
    base = data(data.REF_AREA == country, :);
    variables = unique(base.category);
    
    for i = 1:length(variables)
        variable = variables(i);  % Extract variable as a string
        
        % Filter by variable
        base1 = base(base.category == variable, :);
        
        % Convert values to log and apply HP filter
        values = log(base1.OBS_VALUE); 
        [trend,cycle] = hpfilter(values);
        
        % Store results
        out = table(base1.TIME_PERIOD, values, trend, cycle, ...
                    base1.REF_AREA, base1.category, ...
                    'VariableNames', {'TIME_PERIOD', 'x', 'trend', 'cycle', 'country', 'variable'});
        
        % Append to results
        hp_results = [hp_results; out]; 
    end
end

% Initialize an empty table for results
table_results_ = table( ...
    categorical([], 0, 'Ordinal', false), ...  % country as categorical
    categorical([], 0, 'Ordinal', false), ...  % variable as categorical
    zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ... % Numeric variables as double
    'VariableNames', {'country', 'variable', 'Volatility', 'Relative_Vol_GDP', 'Correlation', 'Autocorrelation'} ...
);

% Loop again to calculate additional metrics
for n = 1:length(countries)
    country = countries(n);  % Extract country as a string
    
    % Filter by country
    base = hp_results(hp_results.country == country, :);
    variables = unique(base.variable);
    
    for i = 1:length(variables)
        variable = variables(i);  % Extract variable as a string
        
        % Filter by variable
        base1 = base(base.variable == variable, :);
        
        % Calculate lag for autocorrelation
        base1.lag = [NaN; base1.cycle(1:end-1)];
        
        % Filter GDP data for the same country
        GDP = hp_results(hp_results.variable == "GDP" & hp_results.country == country, :);
        GDP.Properties.VariableNames{'cycle'} = 'GDP';
        GDP = GDP(:, {'TIME_PERIOD', 'country', 'GDP'});
        
        % Compute volatility
        volatility = rowfun(@(x) 100 * std(x), base1, 'InputVariables', 'cycle', 'GroupingVariables', {'country', 'variable'});
        volatility.Properties.VariableNames{'Var4'} = 'Volatility';
        
        % Compute correlation with GDP
        correlation = innerjoin(base1, GDP, 'Keys', {'TIME_PERIOD', 'country'});
        correlation = rowfun(@(x, y) corr(x, y, 'Rows', 'complete'), ...
                             correlation, 'InputVariables', {'cycle', 'GDP'}, ...
                             'GroupingVariables', {'country', 'variable'}, ...
                             'OutputVariableNames', {'Correlation'});
        
        % Compute autocorrelation
        autocorrelation = rowfun(@(x, y) corr(x, y, 'Rows', 'complete'), base1, 'InputVariables', {'cycle', 'lag'}, 'GroupingVariables', {'country', 'variable'});
        autocorrelation.Properties.VariableNames{'Var4'} = 'Autocorrelation';
        
        % Compute relative volatility with GDP
        rel_vol_GDP = innerjoin(base1, GDP, 'Keys', {'TIME_PERIOD', 'country'});
        rel_vol_GDP = rowfun(@(x, y) std(x, 'omitnan') / std(y, 'omitnan'), rel_vol_GDP, 'InputVariables', {'cycle', 'GDP'}, 'GroupingVariables', {'country', 'variable'});
        rel_vol_GDP.Properties.VariableNames{'Var4'} = 'Relative_Vol_GDP';
        
        % Select relevant columns
        volatility = volatility(:, {'country', 'variable', 'Volatility'});
        rel_vol_GDP = rel_vol_GDP(:, {'country', 'variable', 'Relative_Vol_GDP'});
        correlation = correlation(:, {'country', 'variable', 'Correlation'});
        autocorrelation = autocorrelation(:, {'country', 'variable', 'Autocorrelation'});

        % Combine results
        table_results = outerjoin(volatility, rel_vol_GDP, 'Keys', {'country', 'variable'}, 'MergeKeys', true);
        table_results = outerjoin(table_results, correlation, 'Keys', {'country', 'variable'}, 'MergeKeys', true);
        table_results = outerjoin(table_results, autocorrelation, 'Keys', {'country', 'variable'}, 'MergeKeys', true);
        
        % Append to results
        table_results_ = [table_results_; table_results];
    end
end

table_results = table_results_

% The object table_results contains the results of the second moment
% computations. 

% For work on the plots and the data cleaning applied see the file
% project_Fiallos_Vallat.qmd 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%   END OF SCRIPT  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%