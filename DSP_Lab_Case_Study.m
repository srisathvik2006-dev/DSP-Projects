%% ROBUST SPEECH ENHANCEMENT
% Spectral Subtraction vs Wiener Filtering
% Under Varying Noise Conditions
%
% 4 Noise Types x 5 SNR Levels x 2 Algorithms = 40 experiments
%
% Metrics:
%   Input SNR
%   Output SNR
%   SNR Improvement
%   RMSE
%
% MATLAB + Signal Processing Toolbox

clear;
clc;
close all;

%% ================================================================
%  1. USER SETTINGS
%  ================================================================

% Set to true if you want to use your own WAV file.
useCustomSpeech = false;

% If using your own speech:
speechFile = 'my_speech.wav';

% Required SNR values
snrValues = [-5 0 5 10 15];

% Noise names
noiseNames = {'White Gaussian', ...
              'Babble', ...
              'Industrial', ...
              'Traffic'};

% Reproducibility
rng(10);

% Frame parameters
frameLength = 512;
hopLength   = 256;

% Noise-only calibration duration
noiseCalDuration = 0.5;

% Spectral subtraction parameters
alpha = 1.5;
spectralFloor = 0.02;


%% ================================================================
%  2. LOAD CLEAN SPEECH
%  ================================================================

if useCustomSpeech

    [speech, Fs] = audioread(speechFile);

else

    % MATLAB Signal Processing Toolbox example speech
    load mtlb;

    speech = mtlb;
    Fs = Fs;

end

% Convert stereo to mono
if size(speech,2) > 1
    speech = mean(speech,2);
end

% Remove DC component
speech = speech - mean(speech);

% Normalize
speech = speech / (max(abs(speech)) + eps);

% Limit duration if desired
maxDuration = 8;

Nmax = min(length(speech), round(maxDuration*Fs));
speech = speech(1:Nmax);

t = (0:length(speech)-1)'/Fs;

fprintf('\nSpeech sampling frequency: %d Hz\n', Fs);
fprintf('Speech duration: %.2f seconds\n', length(speech)/Fs);


%% ================================================================
%  3. NOISE CALIBRATION SEGMENT
%  ================================================================

noiseCalSamples = round(noiseCalDuration * Fs);

% This segment is used as a noise-only calibration region.
% It is NOT included in the final speech-quality metrics.

fprintf('Noise calibration duration: %.2f seconds\n', ...
    noiseCalDuration);


%% ================================================================
%  4. RESULTS STORAGE
%  ================================================================

results = table();

resultIndex = 1;


%% ================================================================
%  5. RUN ALL 40 EXPERIMENTS
%  ================================================================

fprintf('\n====================================================\n');
fprintf('STARTING 40 EXPERIMENTS\n');
fprintf('====================================================\n');

for noiseIndex = 1:length(noiseNames)

    noiseName = noiseNames{noiseIndex};

    fprintf('\nNoise Type: %s\n', noiseName);

    % Generate one base noise realization
    baseNoise = generateNoise( ...
        noiseIndex, ...
        length(speech) + noiseCalSamples, ...
        Fs, ...
        speech);

    % Normalize base noise
    baseNoise = baseNoise(:);
    baseNoise = baseNoise / ...
        (sqrt(mean(baseNoise.^2)) + eps);


    for snrIndex = 1:length(snrValues)

        targetSNR = snrValues(snrIndex);

        %% --------------------------------------------------------
        %  Create noise with required SNR
        %  ---------------------------------------------------------

        speechPower = mean(speech.^2);

        noiseSpeechPart = baseNoise(noiseCalSamples+1:end);

        noisePower = mean(noiseSpeechPart.^2);

        requiredNoisePower = ...
            speechPower / 10^(targetSNR/10);

        scaleFactor = ...
            sqrt(requiredNoisePower / ...
            (noisePower + eps));

        scaledNoise = baseNoise * scaleFactor;

        calibrationNoise = ...
            scaledNoise(1:noiseCalSamples);

        speechNoise = ...
            scaledNoise(noiseCalSamples+1:end);


        %% --------------------------------------------------------
        %  Create noisy speech
        %  ---------------------------------------------------------

        noisySpeech = speech + speechNoise;

        % Input SNR measured numerically
        actualInputSNR = 10*log10( ...
            sum(speech.^2) / ...
            (sum(speechNoise.^2) + eps));


        %% --------------------------------------------------------
        %  Add noise-only calibration segment
        %  ---------------------------------------------------------

        analysisSignal = ...
            [calibrationNoise; noisySpeech];


        %% --------------------------------------------------------
        %  SPECTRAL SUBTRACTION
        %  ---------------------------------------------------------

        enhancedSS = spectralSubtraction( ...
            analysisSignal, ...
            Fs, ...
            frameLength, ...
            hopLength, ...
            noiseCalSamples, ...
            alpha, ...
            spectralFloor);

        % Remove calibration region
        enhancedSS = ...
            enhancedSS(noiseCalSamples+1: ...
            noiseCalSamples+length(speech));


        %% --------------------------------------------------------
        %  WIENER FILTER
        %  ---------------------------------------------------------

        enhancedWiener = wienerEnhancement( ...
            analysisSignal, ...
            Fs, ...
            frameLength, ...
            hopLength, ...
            noiseCalSamples);

        % Remove calibration region
        enhancedWiener = ...
            enhancedWiener(noiseCalSamples+1: ...
            noiseCalSamples+length(speech));


        %% --------------------------------------------------------
        %  Calculate metrics
        %  ---------------------------------------------------------

        % Spectral Subtraction
        outputSNR_SS = calculateOutputSNR( ...
            speech, enhancedSS);

        improvementSS = ...
            outputSNR_SS - actualInputSNR;

        rmseSS = sqrt(mean( ...
            (speech-enhancedSS).^2));


        % Wiener Filtering
        outputSNR_W = calculateOutputSNR( ...
            speech, enhancedWiener);

        improvementW = ...
            outputSNR_W - actualInputSNR;

        rmseW = sqrt(mean( ...
            (speech-enhancedWiener).^2));


        %% --------------------------------------------------------
        %  Store Spectral Subtraction result
        %  ---------------------------------------------------------

        results(noiseIndex*0 + resultIndex,:) = table( ...
            string(noiseName), ...
            targetSNR, ...
            actualInputSNR, ...
            string("Spectral Subtraction"), ...
            outputSNR_SS, ...
            improvementSS, ...
            rmseSS, ...
            'VariableNames', ...
            {'NoiseType', ...
             'TargetInputSNR', ...
             'ActualInputSNR', ...
             'Algorithm', ...
             'OutputSNR', ...
             'SNRImprovement', ...
             'RMSE'});

        resultIndex = resultIndex + 1;


        %% --------------------------------------------------------
        %  Store Wiener result
        %  ---------------------------------------------------------

        results(resultIndex,:) = table( ...
            string(noiseName), ...
            targetSNR, ...
            actualInputSNR, ...
            string("Wiener Filtering"), ...
            outputSNR_W, ...
            improvementW, ...
            rmseW, ...
            'VariableNames', ...
            {'NoiseType', ...
             'TargetInputSNR', ...
             'ActualInputSNR', ...
             'Algorithm', ...
             'OutputSNR', ...
             'SNRImprovement', ...
             'RMSE'});

        resultIndex = resultIndex + 1;


        %% --------------------------------------------------------
        %  Display current experiment
        %  ---------------------------------------------------------

        fprintf( ...
            'SNR = %5.1f dB | SS = %7.2f dB | Wiener = %7.2f dB\n', ...
            targetSNR, ...
            improvementSS, ...
            improvementW);


        %% --------------------------------------------------------
        %  Save representative signal for plotting
        %  ---------------------------------------------------------

        % Use 5 dB condition as representative visualization
        if targetSNR == 5 && noiseIndex == 1

            representativeNoisy = noisySpeech;
            representativeSS = enhancedSS;
            representativeWiener = enhancedWiener;
            representativeNoise = speechNoise;

        end

    end

end


%% ================================================================
%  6. SAVE RESULTS
%  ================================================================

writetable(results, 'results_summary.csv');

fprintf('\nResults saved as results_summary.csv\n');


%% ================================================================
%  7. DISPLAY COMPLETE RESULTS
%  ================================================================

disp(results);


%% ================================================================
%  8. REPRESENTATIVE WAVEFORMS
%  ================================================================

figure('Name','Representative Waveforms');

tiledlayout(4,1);

nexttile;
plot(t,speech);
grid on;
title('Clean Speech');
xlabel('Time (s)');
ylabel('Amplitude');

nexttile;
plot(t,representativeNoise);
grid on;
title('Noise - White Gaussian, 5 dB SNR');
xlabel('Time (s)');
ylabel('Amplitude');

nexttile;
plot(t,representativeSS);
grid on;
title('Spectral Subtraction Output');
xlabel('Time (s)');
ylabel('Amplitude');

nexttile;
plot(t,representativeWiener);
grid on;
title('Wiener Filtering Output');
xlabel('Time (s)');
ylabel('Amplitude');


%% ================================================================
%  9. SPECTROGRAM COMPARISON
%  ================================================================

figure('Name','Spectrogram Comparison');

tiledlayout(4,1);

nexttile;
spectrogram(speech, ...
    hamming(frameLength), ...
    frameLength-hopLength, ...
    frameLength, ...
    Fs, ...
    'yaxis');
title('Clean Speech Spectrogram');

nexttile;
spectrogram(representativeNoisy, ...
    hamming(frameLength), ...
    frameLength-hopLength, ...
    frameLength, ...
    Fs, ...
    'yaxis');
title('Noisy Speech Spectrogram');

nexttile;
spectrogram(representativeSS, ...
    hamming(frameLength), ...
    frameLength-hopLength, ...
    frameLength, ...
    Fs, ...
    'yaxis');
title('Spectral Subtraction Spectrogram');

nexttile;
spectrogram(representativeWiener, ...
    hamming(frameLength), ...
    frameLength-hopLength, ...
    frameLength, ...
    Fs, ...
    'yaxis');
title('Wiener Filtering Spectrogram');


%% ================================================================
%  10. PERFORMANCE PLOTS
%  ================================================================

% Average SNR improvement by algorithm and SNR

figure('Name','SNR Improvement vs Input SNR');

hold on;
grid on;

for algorithmName = ...
        ["Spectral Subtraction","Wiener Filtering"]

    algorithmRows = ...
        results.Algorithm == algorithmName;

    x = [];
    y = [];

    for snrValue = snrValues

        rows = algorithmRows & ...
            results.TargetInputSNR == snrValue;

        x(end+1) = snrValue;
        y(end+1) = mean( ...
            results.SNRImprovement(rows));

    end

    plot(x,y,'-o','LineWidth',1.5, ...
        'DisplayName',char(algorithmName));

end

xlabel('Input SNR (dB)');
ylabel('Average SNR Improvement (dB)');
title('Average SNR Improvement vs Input SNR');
legend('Location','best');


%% ================================================================
%  11. OUTPUT SNR COMPARISON
%  ================================================================

figure('Name','Output SNR vs Input SNR');

hold on;
grid on;

for algorithmName = ...
        ["Spectral Subtraction","Wiener Filtering"]

    algorithmRows = ...
        results.Algorithm == algorithmName;

    x = [];
    y = [];

    for snrValue = snrValues

        rows = algorithmRows & ...
            results.TargetInputSNR == snrValue;

        x(end+1) = snrValue;
        y(end+1) = mean( ...
            results.OutputSNR(rows));

    end

    plot(x,y,'-o','LineWidth',1.5, ...
        'DisplayName',char(algorithmName));

end

xlabel('Input SNR (dB)');
ylabel('Output SNR (dB)');
title('Average Output SNR vs Input SNR');
legend('Location','best');


%% ================================================================
%  12. RMSE COMPARISON
%  ================================================================

figure('Name','RMSE vs Input SNR');

hold on;
grid on;

for algorithmName = ...
        ["Spectral Subtraction","Wiener Filtering"]

    algorithmRows = ...
        results.Algorithm == algorithmName;

    x = [];
    y = [];

    for snrValue = snrValues

        rows = algorithmRows & ...
            results.TargetInputSNR == snrValue;

        x(end+1) = snrValue;
        y(end+1) = mean( ...
            results.RMSE(rows));

    end

    plot(x,y,'-o','LineWidth',1.5, ...
        'DisplayName',char(algorithmName));

end

xlabel('Input SNR (dB)');
ylabel('RMSE');
title('Average RMSE vs Input SNR');
legend('Location','best');


%% ================================================================
%  13. NOISE-WISE COMPARISON
%  ================================================================

figure('Name','Noise-wise SNR Improvement');

averageImprovement = zeros(4,2);

for n = 1:4

    for a = 1:2

        if a == 1
            alg = "Spectral Subtraction";
        else
            alg = "Wiener Filtering";
        end

        rows = ...
            results.NoiseType == noiseNames{n} & ...
            results.Algorithm == alg;

        averageImprovement(n,a) = ...
            mean(results.SNRImprovement(rows));

    end

end

bar(averageImprovement);

grid on;

set(gca,'XTickLabel',noiseNames);

xlabel('Noise Type');
ylabel('Average SNR Improvement (dB)');
title('Average SNR Improvement Across Noise Types');

legend('Spectral Subtraction', ...
       'Wiener Filtering', ...
       'Location','best');


%% ================================================================
%  14. OVERALL ALGORITHM COMPARISON
%  ================================================================

figure('Name','Overall Algorithm Comparison');

overallSS = mean( ...
    results.SNRImprovement( ...
    results.Algorithm == "Spectral Subtraction"));

overallW = mean( ...
    results.SNRImprovement( ...
    results.Algorithm == "Wiener Filtering"));

bar([overallSS overallW]);

grid on;

set(gca,'XTickLabel', ...
    {'Spectral Subtraction', ...
     'Wiener Filtering'});

ylabel('Mean SNR Improvement (dB)');
title('Overall Enhancement Performance');


%% ================================================================
%  15. BEST METHOD FOR EACH CONDITION
%  ================================================================

fprintf('\n====================================================\n');
fprintf('CONDITION-WISE COMPARISON\n');
fprintf('====================================================\n');

for n = 1:4

    for s = 1:length(snrValues)

        rowsSS = ...
            results.NoiseType == noiseNames{n} & ...
            results.TargetInputSNR == snrValues(s) & ...
            results.Algorithm == "Spectral Subtraction";

        rowsW = ...
            results.NoiseType == noiseNames{n} & ...
            results.TargetInputSNR == snrValues(s) & ...
            results.Algorithm == "Wiener Filtering";

        ss = results.SNRImprovement(rowsSS);
        ww = results.SNRImprovement(rowsW);

        if ss > ww
            winner = 'Spectral Subtraction';
        elseif ww > ss
            winner = 'Wiener Filtering';
        else
            winner = 'Equal';
        end

        fprintf('%-20s | %5.1f dB | Winner: %s\n', ...
            noiseNames{n}, ...
            snrValues(s), ...
            winner);

    end

end


%% ================================================================
%  16. FINISH
%  ================================================================

fprintf('\n====================================================\n');
fprintf('ALL 40 EXPERIMENTS COMPLETED SUCCESSFULLY.\n');
fprintf('====================================================\n');


%% ================================================================
%  LOCAL FUNCTION 1: NOISE GENERATION
%  ================================================================

function noise = generateNoise(type,N,Fs,speech)

switch type

    case 1
        % ---------------------------------------------------------
        % WHITE GAUSSIAN NOISE
        % ---------------------------------------------------------
        noise = randn(N,1);


    case 2
        % ---------------------------------------------------------
        % SIMULATED BABBLE NOISE
        % ---------------------------------------------------------

        speech = speech(:);

        if length(speech) < N
            speech = repmat(speech, ...
                ceil(N/length(speech)),1);
        end

        speech = speech(1:N);

        % Create multiple shifted versions
        babble = zeros(N,1);

        numberOfTalkers = 5;

        for k = 1:numberOfTalkers

            shift = randi([1 min(Fs,N-1)]);

            shifted = circshift(speech,shift);

            % Random amplitude
            amplitude = 0.5 + rand;

            babble = babble + ...
                amplitude*shifted;

        end

        % Add small independent component
        babble = babble + ...
            0.15*randn(N,1);

        noise = babble;


    case 3
        % ---------------------------------------------------------
        % SIMULATED INDUSTRIAL / FACTORY NOISE
        % ---------------------------------------------------------

        t = (0:N-1)'/Fs;

        broadband = 0.5*randn(N,1);

        % Low frequency machinery component
        lowFreq = ...
            0.7*sin(2*pi*120*t) + ...
            0.4*sin(2*pi*240*t);

        % Tonal machinery components
        tonal = ...
            0.25*sin(2*pi*850*t) + ...
            0.20*sin(2*pi*1250*t);

        noise = broadband + ...
                lowFreq + tonal;


    case 4
        % ---------------------------------------------------------
        % SIMULATED TRAFFIC / VEHICLE NOISE
        % ---------------------------------------------------------

        raw = randn(N,1);

        % Low-pass filter
        [b,a] = butter(4,400/(Fs/2),'low');

        lowFrequencyNoise = filter(b,a,raw);

        % Slowly varying amplitude envelope
        t = (0:N-1)'/Fs;

        envelope = ...
            1 + 0.35*sin(2*pi*0.4*t);

        broadband = 0.25*randn(N,1);

        noise = ...
            envelope.*lowFrequencyNoise + ...
            broadband;


    otherwise

        error('Invalid noise type.');

end

noise = noise(:);

end


%% ================================================================
%  LOCAL FUNCTION 2: SPECTRAL SUBTRACTION
%  ================================================================

function enhanced = spectralSubtraction( ...
    signal,Fs,frameLength,hopLength, ...
    noiseCalSamples,alpha,spectralFloor)

signal = signal(:);

N = length(signal);

window = hamming(frameLength,'periodic');

numberOfFrames = ...
    ceil((N-frameLength)/hopLength) + 1;

% Zero padding
totalLength = ...
    (numberOfFrames-1)*hopLength + frameLength;

paddedSignal = zeros(totalLength,1);

paddedSignal(1:N) = signal;

enhanced = zeros(totalLength,1);

windowSum = zeros(totalLength,1);

% Estimate noise spectrum from calibration segment
numberNoiseFrames = ...
    floor((noiseCalSamples-frameLength)/hopLength)+1;

noisePower = zeros(frameLength,1);

for m = 1:numberNoiseFrames

    startIndex = ...
        (m-1)*hopLength + 1;

    frame = ...
        paddedSignal(startIndex: ...
        startIndex+frameLength-1).*window;

    spectrum = fft(frame);

    noisePower = noisePower + ...
        abs(spectrum).^2;

end

noisePower = ...
    noisePower/(numberNoiseFrames+eps);


% Enhancement
for m = 1:numberOfFrames

    startIndex = ...
        (m-1)*hopLength + 1;

    frame = ...
        paddedSignal(startIndex: ...
        startIndex+frameLength-1).*window;

    spectrum = fft(frame);

    magnitude = abs(spectrum);

    phase = angle(spectrum);

    powerSpectrum = magnitude.^2;

    estimatedPower = ...
        powerSpectrum - alpha*noisePower;

    floorPower = ...
        spectralFloor*powerSpectrum;

    estimatedPower = ...
        max(estimatedPower,floorPower);

    enhancedMagnitude = ...
        sqrt(max(estimatedPower,0));

    enhancedSpectrum = ...
        enhancedMagnitude .* exp(1j*phase);

    enhancedFrame = ...
        real(ifft(enhancedSpectrum));

    enhanced(startIndex: ...
        startIndex+frameLength-1) = ...
        enhanced(startIndex: ...
        startIndex+frameLength-1) + ...
        enhancedFrame.*window;

    windowSum(startIndex: ...
        startIndex+frameLength-1) = ...
        windowSum(startIndex: ...
        startIndex+frameLength-1) + ...
        window.^2;

end

enhanced = ...
    enhanced ./ (windowSum + eps);

enhanced = enhanced(1:N);

end


%% ================================================================
%  LOCAL FUNCTION 3: WIENER FILTER
%  ================================================================

function enhanced = wienerEnhancement( ...
    signal,Fs,frameLength,hopLength,noiseCalSamples)

signal = signal(:);

N = length(signal);

window = hamming(frameLength,'periodic');

numberOfFrames = ...
    ceil((N-frameLength)/hopLength)+1;

totalLength = ...
    (numberOfFrames-1)*hopLength + frameLength;

paddedSignal = zeros(totalLength,1);

paddedSignal(1:N) = signal;

enhanced = zeros(totalLength,1);

windowSum = zeros(totalLength,1);


% ---------------------------------------------------------------
% Estimate noise power spectrum
% ---------------------------------------------------------------

numberNoiseFrames = ...
    floor((noiseCalSamples-frameLength)/hopLength)+1;

noisePower = zeros(frameLength,1);

for m = 1:numberNoiseFrames

    startIndex = ...
        (m-1)*hopLength+1;

    frame = ...
        paddedSignal(startIndex: ...
        startIndex+frameLength-1).*window;

    spectrum = fft(frame);

    noisePower = noisePower + ...
        abs(spectrum).^2;

end

noisePower = ...
    noisePower/(numberNoiseFrames+eps);


% ---------------------------------------------------------------
% Wiener enhancement
% ---------------------------------------------------------------

for m = 1:numberOfFrames

    startIndex = ...
        (m-1)*hopLength+1;

    frame = ...
        paddedSignal(startIndex: ...
        startIndex+frameLength-1).*window;

    spectrum = fft(frame);

    noisyPower = abs(spectrum).^2;

    % Estimate speech power
    speechPower = ...
        max(noisyPower-noisePower,0);

    % Wiener gain
    gain = ...
        speechPower ./ ...
        (speechPower+noisePower+eps);

    % Gain floor for numerical stability
    gain = max(gain,0.05);

    enhancedSpectrum = ...
        gain .* spectrum;

    enhancedFrame = ...
        real(ifft(enhancedSpectrum));

    enhanced(startIndex: ...
        startIndex+frameLength-1) = ...
        enhanced(startIndex: ...
        startIndex+frameLength-1) + ...
        enhancedFrame.*window;

    windowSum(startIndex: ...
        startIndex+frameLength-1) = ...
        windowSum(startIndex: ...
        startIndex+frameLength-1) + ...
        window.^2;

end

enhanced = ...
    enhanced ./ (windowSum+eps);

enhanced = enhanced(1:N);

end


%% ================================================================
%  LOCAL FUNCTION 4: OUTPUT SNR
%  ================================================================

function snrValue = calculateOutputSNR(clean,enhanced)

clean = clean(:);
enhanced = enhanced(:);

% Match lengths
N = min(length(clean),length(enhanced));

clean = clean(1:N);
enhanced = enhanced(1:N);

errorSignal = clean-enhanced;

snrValue = ...
    10*log10( ...
    sum(clean.^2) / ...
    (sum(errorSignal.^2)+eps));

end