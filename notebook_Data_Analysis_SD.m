% Load in initializing variables


voltConv = 0.000000091555527603759401; % Neurolynx saves data in a unitless value, we need this to convert it to volts
Fs = 1250;
kernel = gaussian(Fs, ceil(8*Fs));
kernel2 = gaussian(10*Fs, ceil(80*Fs));
%%%%%%
user = 'Z'; %'Z' for Zach or 'S' for Shahram for path stuff

switch user
    case 'Z'
        cd('C:\Users\ipzach\Documents\MATLAB\Diabetes-Data-Analysis')
        addpath('C:\Users\ipzach\Documents\MATLAB\Toolbox Zach', ...
            'C:\Users\ipzach\Documents\MATLAB\spectral-analysis-tools')
    case 'S'
        cd('C:\COM\ePhy\dbdb\code\Diabetes-LFP-Analysis')
end
%
load('SpkInfo.mat')
load('chans.mat')
switch user
    case 'Z'
        cd('C:\Users\ipzach\Documents\MATLAB\Data\dbdb electrophy')
    case 'S'
        cd('C:\COM\ePhy\dbdb\Data\dbdb electrophy'); % here is the data
end


animal_list = dir; % create a list of every folder (each one is one animal)


rip.DB2 = [];
rip.DB4 = [];
rip.DBDB2 = [];
rip.DBDB4 = [];

label.DB2 = [];
label.DB4 = [];
label.DBDB2 = [];
label.DBDB4 = [];
intSlo_Store = cell(4, 7);
intSlo0_Store = cell(4, 7);
Co = NaN(4, 7, 7, 3);
PLI = NaN(4, 7, 7, 3);
% Group, Animal, freq_band, Layer_comb
slowing_score = NaN(4, 7, 3);
state_changes = NaN(4, 7);
% Group,Animal,Layer_comb

% Begin parsing data
%%%%%%
for group = 1:4
    % Grab indices of animals in a particular group
    if group == 1
        grouping = 3:9; % DB+ 200D 7
        gn = 'DB+ 200D';
    elseif group == 2
        grouping = 10:14; % DB+ 400D 5
        gn = 'DB+ 400D';
    elseif group == 3
        grouping = [15:18, 20, 21]; % DBDB 200D 6
        gn = 'DBDB 200D';
    elseif group == 4
        grouping = [22, 24:27]; % DBDB 400D 5
        gn = 'DBDB 400D';
    end
    counter = 0;
    
    gamma_pyr = [];
    gamma_slm = [];
    gamma_ctx = [];
    avg_rip = [];
    csd = [];
    dur = [];
    iri = [];
    for cur_animal = grouping
        disp(['Animal: ', num2str(cur_animal)])
        cd(animal_list(cur_animal).name)
        % Get file names of specific animals relevant files
        %%%%%%
        load('SWR_Index.mat'); % load SWR HTD/LTD  indices
        load('REM.mat'); % load HTD/LTD State times
        SWR_files = dir('SWR_R_*'); % Grab the number of files that have SWR event timings (usually 2, sometimes 1 or 3)
        SWR_files = {SWR_files.name}; % throw away useless info
        
        LFP_files = dir('LFP*'); % grab number of LFP files (sometimes 1 or 3 as well)
        LFP_files = {LFP_files.name}; % throw away useless info
        
        counter = counter + 1;
        full_LFP = [];
        state_changes(group, counter) = 0;
        % Check Data fidelity
        %%%%%%
        %%%%%
        % initialize struct for data validation
        single_animal_measures.gamma = [];
        single_animal_measures.CSD = [];
        single_animal_measures.events = [];
        single_animal_measures.events = [];
        single_animal_measures.dur = [];
        single_animal_measures.IRI = [];
        for k = 1:size(SWRLTDIdx,2) % run through each of the LTD periods (where SWRs occur)
            if ~isempty(rem(k).R) % Make sure recording exists
                state_changes(group, counter) = state_changes(group, counter) + length(rem(k).R.start);
            else
                disp(['Rem file missing for animal ', num2str(cur_animal)])
            end % if REM not empty
            load(char(LFP_files(k))); % Load LFP events
            
            LFP = LFPs{1, 2} .* voltConv; % load LFP
            full_LFP = [full_LFP; LFP];
            if ~isempty(SWRLTDIdx(k).R) % makes sure ripple occured during this period
                % Load in animal data
                %%%%%%
                load(char(SWR_files(k))); % Load SWR events
                %%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%% Per Ripple Analysis %%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%
                % Preprocess signal
                %%%%%%
                
                gamma_LFP = BPfilter(LFP, 1250, 30, 60); % isolate gamma frequency band
                LTD_events = SWRevents(SWRLTDIdx(k).R, 1:2); % grab SWRs that occur during this period
                LTD_events(LTD_events <= 625) = NaN;
                LTD_events(LTD_events >= length(LFP)-1250) = NaN;
                LTD_events = rmmissing(LTD_events, 1);
                if isempty(LTD_events)
                    disp(['No LTD events for animal: ', num2str(cur_animal), ' recording: ', num2str(k)])
                end
                
                % initialize temp storage variables
                temp_gamma_pyr = zeros(1, size(LTD_events,1));
                temp_avg_rip = zeros(1876, size(LTD_events,1));
                temp_CSD = zeros(1876, 12, size(LTD_events,1));
                
                for r = 1:size(LTD_events, 1)
                    % gamma power of each ripple
                    temp_gamma_pyr(r) = SignalPower(gamma_LFP(LTD_events(r, 1):LTD_events(r, 2), chans(2, cur_animal)), 1250);
                    temp_avg_rip(:, r) = gamma_LFP(LTD_events(r)-625:LTD_events(r)+1250, chans(2, cur_animal));
                    
                    % Create CSD of each ripple
                    temp_CSD(:, :, r) = CSDlite(LFP(LTD_events(r)-625:LTD_events(r)+1250, chans(2, cur_animal)-5:chans(2, cur_animal)+6), Fs, 1e-4);
                    %csd = save_check(csd, temp_CSD);
                end
                single_animal_measures.gamma = [single_animal_measures.gamma, temp_gamma_pyr];
                single_animal_measures.CSD = cat(3, single_animal_measures.CSD, temp_CSD);
                % Concatenate temp variable to storage variable
                %gamma_ctx = [gamma_ctx temp_gamma_ctx];
                gamma_pyr = [gamma_pyr, temp_gamma_pyr];
                %gamma_slm = [gamma_slm temp_gamma_slm];
                avg_rip = [avg_rip, temp_avg_rip];
                csd = cat(3, csd, temp_CSD);
                single_animal_measures.events = [single_animal_measures.events; LTD_events];
                single_animal_measures.dur = [single_animal_measures.dur; LTD_events(:, 2) - LTD_events(:, 1)];
                single_animal_measures.IRI = [single_animal_measures.IRI; diff(LTD_events(:, 1))];
                iri = [iri; diff(LTD_events(:, 1))];
                % Save all individual ripples for basic analysis
                if group == 1
                    [rip.DB2, label.DB2] = label_ripples(rip.DB2, label.DB2, LTD_events, counter);
                elseif group == 2
                    [rip.DB4, label.DB4] = label_ripples(rip.DB4, label.DB4, LTD_events, counter);
                elseif group == 3
                    [rip.DBDB2, label.DBDB2] = label_ripples(rip.DBDB2, label.DBDB2, LTD_events, counter);
                elseif group == 4
                    [rip.DBDB4, label.DBDB4] = label_ripples(rip.DBDB4, label.DBDB4, LTD_events, counter);
                end
            else
                disp(['SWRLTDIdx is empty/missing for animal ', num2str(cur_animal) ' recording: ' num2str(k)])
            end %is empty SWRLTD
            
        end % for k SWRLTDIdx
        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Per animal analysis %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        if ~isempty(full_LFP)
            for layer = 1:3
                %%% Slowing score
                %%%%%%%%%%%%%%%%%
                % BP filter LFP for low and high frequencies
                single_channel = full_LFP(:, chans(layer, cur_animal));
                low_freq = BPfilter(single_channel, 1250, 1, 8);
                high_freq = BPfilter(single_channel, 1250, 9, 30);
                
                % Calculate ratio of signal powers
                slowing_score(group, counter, layer) = SignalPower(low_freq, 1250) ./ SignalPower(high_freq, 1250);
                single_animal_measures.SS(layer) = slowing_score(group, counter, layer);
                % Group, Band, Animal, Layer
                
                % calculate Spectral exponent
                [PSD, frex] = pwelch(single_channel, 2*Fs, Fs, [], Fs);
                frBand = [1, 40];
                frBins = dsearchn(frex, frBand(1)):dsearchn(frex, frBand(2));
                XX = frex(frBins);
                YY = PSD(frBins);
                robRegMeth = 'ols';
                doPlot = 00; %figure
                thisCol = [0, 0, 1];
                [intSlo, stat, Pows, Deviants, stat0, intSlo0] = fitPowerLaw3steps(XX, YY, robRegMeth, doPlot, thisCol);
                Pows_store(group, counter) = Pows;
                intSlo_Store{group, counter, layer} = intSlo;
                intSlo0_Store{group, counter, layer} = intSlo0;
                single_animal_measures.SE(layer) = intSlo0(2);
                % Coherence and PLI
                %%%%%%%%%%%%%
                switch layer
                    case 1
                        A = 1;
                        B = 2;
                        compare = 'Cortex-Pyr';
                    case 2
                        A = 1;
                        B = 3;
                        compare = 'Cortex-Slm';
                    case 3
                        A = 2;
                        B = 3;
                        compare = 'Pyr-Slm';
                end % switch layer
                disp(compare)
                % Assign single channels to run coherence on
                
                A_LFP = full_LFP(:, chans(A, cur_animal));
                B_LFP = full_LFP(:, chans(B, cur_animal));
                % create a vector of indiviudal frequencies to calculate
                % coherence
                for freq_band = 1:7
                    switch freq_band
                        case 1
                            range = linspace(0.1, 3, 20);
                            A_filt = BPfilter(A_LFP, 1250, 0.1, 3);
                            B_filt = BPfilter(B_LFP, 1250, 0.1, 3);
                        case 2
                            range = linspace(4, 7, 20);
                            A_filt = BPfilter(A_LFP, 1250, 4, 7);
                            B_filt = BPfilter(B_LFP, 1250, 4, 7);
                        case 3
                            range = linspace(8, 13, 20);
                            A_filt = BPfilter(A_LFP, 1250, 8, 13);
                            B_filt = BPfilter(B_LFP, 1250, 8, 13);
                        case 4
                            range = linspace(13, 30, 20);
                            A_filt = BPfilter(A_LFP, 1250, 13, 30);
                            B_filt = BPfilter(B_LFP, 1250, 13, 30);
                        case 5
                            range = linspace(30, 58, 20);
                            A_filt = BPfilter(A_LFP, 1250, 30, 58);
                            B_filt = BPfilter(B_LFP, 1250, 30, 58);
                        case 6
                            range = linspace(62, 200, 20);
                            A_filt = BPfilter(A_LFP, 1250, 62, 200);
                            B_filt = BPfilter(B_LFP, 1250, 62, 200);
                        case 7
                            range = linspace(0, 200, 50);
                            A_filt = BPfilter(A_LFP, 1250, 0.1, 200);
                            B_filt = BPfilter(B_LFP, 1250, 0.1, 200);
                    end % switch iBand
                    % Run coherence and average outputs for each frequency
                    % band
                    % Group, Band, recording, Animal, Layer/layer
                    % Co(1: group id, animal, frequency band, layer
                    % comparison (check compare variable))
                    % comparison)
                    Co(group, counter, freq_band, layer) = nanmean(mscohere(A_LFP, B_LFP, hamming(12500), [], range, 1250));
                    PLI(group, counter, freq_band, layer) = PLV(angle(hilbert(A_filt))', angle(hilbert(B_filt))');
                    single_animal_measures.Co(layer, freq_band) = Co(group, counter, freq_band, layer);
                    single_animal_measures.PLI(layer, freq_band) = PLI(group, counter, freq_band, layer);
                    single_animal_measures.LFP = full_LFP;
                    
                end % frequency band
            end % layer
        else
            disp(['LFP is empty for animal ', num2str(cur_animal)])
        end % if
        cd ..
        UCSF_single_animal_excel(single_animal_measures, [gn, '_', num2str(counter)], user);
        
        
        %save(['C:\COM\ePhy\dbdb\Data\Outputs\Data\SingleAnimal\' gn '_' num2str(counter) ],'single_animal_measures')
    end % animal
    % Save data to variable outside loop
    if group == 1
        %Gamma.DB2_Ctx = gamma_ctx;
        Gamma.DB2_Pyr = gamma_pyr;
        %Gamma.DB2_SLM = gamma_slm;
        CSD.DB2 = csd;
        rip_wav.DB2 = avg_rip;
        iri_all.DB2 = iri;
    elseif group == 2
        %Gamma.DB4_Ctx = gamma_ctx;
        Gamma.DB4_Pyr = gamma_pyr;
        %Gamma.DB4_SLM = gamma_slm;
        CSD.DB4 = csd;
        rip_wav.DB4 = avg_rip;
        iri_all.DB4 = iri;
    elseif group == 3
        %Gamma.DBDB2_Ctx = gamma_ctx;
        Gamma.DBDB2_Pyr = gamma_pyr;
        %Gamma.DBDB2_SLM = gamma_slm;
        CSD.DBDB2 = csd;
        rip_wav.DBDB2 = avg_rip;
        iri_all.DBDB2 = iri;
    elseif group == 4
        %Gamma.DBDB4_Ctx = gamma_ctx;
        Gamma.DBDB4_Pyr = gamma_pyr;
        %Gamma.DBDB4_SLM = gamma_slm;
        CSD.DBDB4 = csd;
        rip_wav.DBDB4 = avg_rip;
        iri_all.DBDB4 = iri;
    end % if
end % group
% Group, Animal, freq_band, Layer

%% save processed data
switch user
    case 'Z'
        cd('C:\Users\ipzach\Documents\MATLAB\output\Diabetes-Saved-Files')
    case 'S'
        cd('C:\COM\ePhy\dbdb\Data\Outputs\Data')
end
save('LFP Measures', 'Gamma', 'rip', 'iri_all', 'rip_wav', 'label', 'CSD', 'Co', 'PLI', 'slowing_score', 'state_changes', 'intSlo0_Store', 'intSlo_Store', 'Pows_store')

%MS
% if user == 'S'
%     cd('C:\COM\ePhy\dbdb\Data\Outputs\Data\LFPs');
%     Animal_Number = unique(Animal_Number);
%     for i=1:length(Animal_Number)
%         TmpStr= sprintf("save('Full_LFPs_%d.mat',", Animal_Number(i));
%         TMPSTR1 = sprintf("'Save_Full_LFP_1_%d', ", Animal_Number(i));
%         TMPSTR2 = sprintf("'Save_Full_LFP_2_%d', ", Animal_Number(i));
%         TmpStr = append(TmpStr, TMPSTR1, TMPSTR2);
%         TmpStr = append(TmpStr, "'-v7.3')");
%         disp(['Saving LFP data for animal: ', num2str(Animal_Number(i))]);
%         eval(TmpStr);
%         disp(['Finished saving data for animal: ', num2str(Animal_Number(i))]);
%     end
% end
%ME
