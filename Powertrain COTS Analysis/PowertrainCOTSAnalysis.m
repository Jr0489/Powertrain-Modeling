clc; clear; close all;

%% Powertrain COTS Analysis
% This script accesses the powertrain COTS catalogue Google Spreadsheet and
% then loops through various motor, controller, and cell combinations.

%% COTS Database Imports
[Cell, Controller, Motor] = SpreadsheetImport();

%% Useful Constants

Pack.V = (1:600);    % Pack Voltage [V]
Pack.E = 6.7;    % Pack Energy Capacity [kWh]
Endurance = 22156741.88; % Constant from endurance, sum of Current^2 times each time step
CellCp = 0.902;  % Lithium ion cell specific heat capacity [J/g-K]

%% Powertrain Configuration Sweeping
% Determine feasible voltage range for each Motor / Controller
% combination, then sweep these voltage ranges for every Cell, in order to
% find the Change in Temperature vs. Voltage for every Motor / Controller /
% Cell combination

Powertrain = struct();

for i = 1 : length(Motor)
    for j = 1 : length(Controller)
        for k = 1 : length(Cell)
            
            Powertrain(i,j,k).Motor = Motor(i);
            Powertrain(i,j,k).Controller = Controller(j);
            Powertrain(i,j,k).Cell = Cell(k);
            
            Powertrain(i,j,k).Flag = [];
            
            Powertrain(i,j,k).VRange = [];      % Defining these as empty in case compatability check
            Powertrain(i,j,k).Series = [];      % Breaks everything... this fix doesn't actually work
            Powertrain(i,j,k).Parallel = [];    %
            Powertrain(i,j,k).Temp = [];        % These should be allocated before the loop somehow
            
            %%% Compatibility Checks
            
            % (Motor / Controller Compat)
            if Controller(j).Voltage < Motor(i).Voltage
               Powertrain(i,j,k).Flag = 'Controller & Motor Voltages Not Compatible | ';
%                break \\\ commented out to continue compatability checks...
%                suppose there's no reason to do this, which rasies the
%                question do we need the debug message or can "Flag" just be
%                a logical value
            end
            
            % (Cell Resistance Has Been Given)
            if isnan(Cell(k).Resistance)
                Powertrain(i,j,k).Flag = [Powertrain(i,j,k).Flag, 'No Cell Resistance Value | '];
%                 break \\\ THIS HAD TO BE COMMENTED OUT BECAUSE IT FUCKS
%                 EVERYTHING UP
            end
            
            %%% Cell Temperature Change
            
            % Find Usable Voltage Range For Each Config
            Powertrain(i,j,k).VRange = [max((min(Powertrain(i,j,k).Motor.Voltage,Powertrain(i,j,k).Controller.Voltage)-200),0) :...
                                        min(Powertrain(i,j,k).Motor.Voltage,Powertrain(i,j,k).Controller.Voltage)];
            
            % Number of Cells in Series / Parallel
            Powertrain(i,j,k).Series = floor(Powertrain(i,j,k).VRange ./ Cell(k).VoltageMax);
            Powertrain(i,j,k).Parallel = floor(Pack.E ./ (Powertrain(i,j,k).Series .* Cell(k).VoltageMax .* Cell(k).Capacity) .* 1000);
            
            % Temperature Change in Cells , Using Cell Ohmic Heat Gen and
            % Cell Thermall Mass
            Powertrain(i,j,k).Temp = (10/6 .* 117.6./Powertrain(i,j,k).VRange).^2 .* (Cell(k).Resistance .*...
                                      Powertrain(i,j,k).Series ./ Powertrain(i,j,k).Parallel) .* Endurance ./...
                                      (Cell(k).Mass .* Powertrain(i,j,k).Series .* Powertrain(i,j,k).Parallel .*...
                                      CellCp);
        end
    end
end

%% Plotting Stuff
figure(1)
for i = 1 : length(Motor)
    for j = 1 : length(Controller)
        for k = 1 : length(Cell)
            
            if isempty(Powertrain(i,j,k).Flag)
                plot(Powertrain(i,j,k).VRange,Powertrain(i,j,k).Temp);
                hold on
            end
            
        end
    end
end

title('A Clever Title')
xlim([100,600]);
xlabel('Powertrain Voltage [V]')
ylim([0,100]);
ylabel('Endurance Temperature Change [C]')

%% Local Functions   
function [Cell, Controller, Motor] = SpreadsheetImport()
    % Import Spreadsheets
    Spreadsheet.Cell = GetGoogleSpreadsheet( ...
        '1yw_K_Wh0mPWjYlOh-KRkUNIrC4Pn1hJrKmpQw7_VwTg', 'Accumulator Cell' );
    
    Spreadsheet.Controller = GetGoogleSpreadsheet( ...
        '1yw_K_Wh0mPWjYlOh-KRkUNIrC4Pn1hJrKmpQw7_VwTg', 'Motor Controller' );
    
    Spreadsheet.Motor = GetGoogleSpreadsheet( ...
        '1yw_K_Wh0mPWjYlOh-KRkUNIrC4Pn1hJrKmpQw7_VwTg', 'Motor' );
    
    % Allocate Cell Structure
    Cell = struct();
    Cell( size(Spreadsheet.Cell, 1) - 7 ).Model = [];
    for i = 8 : size(Spreadsheet.Cell, 1)
        Cell(i-7).Model        = Spreadsheet.Cell(i,1);
        Cell(i-7).Manufacturer = Spreadsheet.Cell(i,2);
        Cell(i-7).Chemistry    = Spreadsheet.Cell(i,3);
        Cell(i-7).Geometry     = Spreadsheet.Cell(i,4);

        Cell(i-7).VoltageNom  = str2double(Spreadsheet.Cell{i,5 });
        Cell(i-7).VoltageMax  = str2double(Spreadsheet.Cell{i,6 });

        Cell(i-7).Capacity     = str2double(Spreadsheet.Cell{i,7 });

        Cell(i-7).Current.Cont = str2double(Spreadsheet.Cell{i,8 });
        Cell(i-7).Current.Max  = str2double(Spreadsheet.Cell{i,9 });

        Cell(i-7).Resistance   = str2double(Spreadsheet.Cell{i,10}) ./ 1000; % Internal resistance [mOhms -> Ohms]

        Cell(i-7).Mass         = str2double(Spreadsheet.Cell{i,21});

        Cell(i-7).Cost         = str2double(Spreadsheet.Cell{i,27});
        end
    
    % Allocate Controller Structure
    Controller = struct();
    Controller( size(Spreadsheet.Controller, 1) - 3 ).Model = [];
    for i = 4 : size(Spreadsheet.Controller, 1)
        Controller(i-3).Model = Spreadsheet.Controller(i,1);
        Controller(i-3).Manufacturer = Spreadsheet.Controller(i,2);

        Controller(i-3).Voltage = str2double(Spreadsheet.Controller{i,5 });

        Controller(i-3).Current.Cont = str2double(Spreadsheet.Controller{i,7 });
        Controller(i-3).Current.Max = str2double(Spreadsheet.Controller{i,8 });

        Controller(i-3).Mass = str2double(Spreadsheet.Controller{i,20 });
    end
    
    % Allocate Controller Structure
    Motor = struct();
    Motor( size(Spreadsheet.Motor, 1) - 3 ).Model = [];
    for i = 4 : size(Spreadsheet.Motor, 1)
        Motor(i-3).Model = Spreadsheet.Motor(i,1);
        Motor(i-3).Manufacturer = Spreadsheet.Motor(i,2);
        
        Motor(i-3).Voltage = str2double(Spreadsheet.Motor{i,5 });
        
        Motor(i-3).Current.Cont = str2double(Spreadsheet.Motor{i,7 });
        Motor(i-3).Current.Max = str2double(Spreadsheet.Motor{i,8 });
        
        Motor(i-3).Mass = str2double(Spreadsheet.Motor{i,24 });
    end
    
    %%% Local Spreadsheet Import Function
    function Spreadsheet = GetGoogleSpreadsheet(WorkbookID, SheetName)
        % Download a google spreadsheet as csv and import into a Matlab cell array.
        %
        % [DOCID] see the value after 'key=' in your spreadsheet's url
        %           e.g. '0AmQ013fj5234gSXFAWLK1REgwRW02hsd3c'
        %
        % [result] cell array of the the values in the spreadsheet
        %
        % IMPORTANT: The spreadsheet must be shared with the "anyone with the link" option
        %
        % This has no error handling and has not been extensively tested.
        % Please report issues on Matlab FX.
        %
        % DM, Jan 2013

        % https://docs.google.com/spreadsheets/d/{key}/gviz/tq?tqx=out:csv&sheet={sheet_name}

        LoginURL = 'https://www.google.com'; 
        CSVURL = ['https://docs.google.com/spreadsheets/d/', WorkbookID                , ...
                  '/gviz/tq?tqx=out:csv&sheet='            , strrep(SheetName,' ','+') ];

        %Step 1: Go to google.com to collect some cookies
        CookieManager = java.net.CookieManager([], java.net.CookiePolicy.ACCEPT_ALL);
        java.net.CookieHandler.setDefault(CookieManager);
        Handler = sun.net.www.protocol.https.Handler;
        Connection = java.net.URL([],LoginURL,Handler).openConnection();
        Connection.getInputStream();

        %Step 2: Go to the spreadsheet export url and download the csv
        Connection2 = java.net.URL([],CSVURL,Handler).openConnection();
        Spreadsheet = Connection2.getInputStream();
        Spreadsheet = char(ReadStream(Spreadsheet));

        %Step 3: Convert the csv to a cell array
        Spreadsheet = ParseCSV(Spreadsheet);

        % Local Functions
        function out = ReadStream(inStream)
        %READSTREAM Read all bytes from stream to uint8
        %From: http://stackoverflow.com/a/1323535
            import com.mathworks.mlwidgets.io.InterruptibleStreamCopier;
            byteStream = java.io.ByteArrayOutputStream();
            isc = InterruptibleStreamCopier.getInterruptibleStreamCopier();
            isc.copyStream(inStream, byteStream);
            inStream.close();
            byteStream.close();
            out = typecast(byteStream.toByteArray', 'uint8'); 
        end

        function data = ParseCSV(data)
        % Splits data into individual lines
            data = textscan(data,'%s','whitespace','\n');
            data = data{1};
            for ii=1:length(data)
               % For each line, split the string into its comma-delimited units
               % The '%q' format deals with the "quoting" convention appropriately.
               tmp = textscan(data{ii},'%q','delimiter',',');
               data(ii,1:length(tmp{1})) = tmp{1};
            end
        end
    end
end
