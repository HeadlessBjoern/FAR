% FaceMorph / FAR
%
% This code requires PsychToolbox. https://psychtoolbox.org
% This was tested with PsychToolbox version 3.0.15, and with MATLAB R2022a.

%% EEG and ET
% Start recording EEG
disp('STARTING EEG RECORDING...');
initEEG;

% Calibrate ET (Tobii Pro Fusion)
disp('CALIBRATING ET...');
calibrateET;

%% Task
HideCursor(whichScreen);

% Define triggers
TASK_START = 10; % trigger for ET cutting
FIXATION = 15; % trigger for fixation cross
PRESENTATION = 21; % trigger for digit presentation
NF = 31; %trigger for NF condition
NN = 32; %trigger for NN condition
NH = 33;  %trigger for NH condition
TASK_END = 90; % trigger for ET cutting

% Set up equipment parameters
equipment.viewDist = 800;               % Viewing distance in millimetres
equipment.ppm = 3.6;                    % Pixels per millimetre !! NEEDS TO BE SET. USE THE MeasureDpi FUNCTION !!
equipment.greyVal = .5;
equipment.blackVal = 0;
equipment.whiteVal = 1;
equipment.gammaVals = [1 1 1];          % The gamma values for color calibration of the monitor

% Set up stimulus parameters Fixation
stimulus.fixationOn = 1;                % Toggle fixation on (1) or off (0)
stimulus.fixationSize_dva = .50;        % Size of fixation cross in degress of visual angle
stimulus.fixationColor = 1;             % Color of fixation cross (1 = white; 0 = black)
stimulus.fixationLineWidth = 3;         % Line width of fixation cross
stimulus.regionHeight_dva = 7.3;
stimulus.regionWidth_dva = 4;
stimulus.regionEccentricity_dva = 3;

% Set up color parameters
color.textVal = 0;                  % Color of text
color.targetVal = 1;

% Set up text parameters
text.color = 0;                     % Color of text (0 = black)

startExperimentText = ['You will see a number of faces in a row. \n\n' ...
    '\n\n' ...
    'Please look at the center of the screen. \n\n' ...
    '\n\n' ...
    'Press any key to start.'];

% Shuffle rng for random elements
rng('default');
rng('shuffle');                     % Use MATLAB twister for rng

% Set up Psychtoolbox Pipeline
AssertOpenGL;

% Imaging set up
screenID = whichScreen;
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'SimpleGamma');
PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');
Screen('Preference', 'SkipSyncTests', 0); % For linux (can be 0)

% Window set-up
[ptbWindow, winRect] = PsychImaging('OpenWindow', screenID, equipment.greyVal);
PsychColorCorrection('SetEncodingGamma', ptbWindow, equipment.gammaVals);
[screenWidth, screenHeight] = RectSize(winRect);
screenCentreX = round(screenWidth/2);
screenCentreY = round(screenHeight/2);
flipInterval = Screen('GetFlipInterval', ptbWindow);
Screen('BlendFunction', ptbWindow, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
experiment.runPriority = MaxPriority(ptbWindow);

% Set font size for instructions and stimuli
Screen('TextSize', ptbWindow, 20);

global psych_default_colormode;                     % Sets colormode to be unclamped 0-1 range.
psych_default_colormode = 1;

global ptb_drawformattedtext_disableClipping;       % Disable clipping of text
ptb_drawformattedtext_disableClipping = 1;

% Calculate equipment parameters
equipment.mpd = (equipment.viewDist/2)*tan(deg2rad(2*stimulus.regionEccentricity_dva))/stimulus.regionEccentricity_dva; % Millimetres per degree
equipment.ppd = equipment.ppm*equipment.mpd;    % Pixels per degree

% Fix coordiantes for fixation cross
stimulus.fixationSize_pix = round(stimulus.fixationSize_dva*equipment.ppd);
fixHorizontal = [round(-stimulus.fixationSize_pix/2) round(stimulus.fixationSize_pix/2) 0 0];
fixVertical = [0 0 round(-stimulus.fixationSize_pix/2) round(stimulus.fixationSize_pix/2)];
fixCoords = [fixHorizontal; fixVertical];

% Create data structure for preallocating data
data = struct;

% Show task instruction text
DrawFormattedText(ptbWindow,startExperimentText,'center','center',color.textVal);
startExperimentTime = Screen('Flip',ptbWindow);
disp('Participant is reading the instructions');
waitResponse = 1;
while waitResponse
    [time, keyCode] = KbWait(-1,2);
    waitResponse = 0;
end

Screen('DrawDots',ptbWindow, backPos, backDiameter, backColor,[],1);
endTime = Screen('Flip',ptbWindow);

% Send triggers for start of task (ET cutting)
Eyelink('Message', num2str(TASK_START));
Eyelink('command', 'record_status_message "START"');
sendtrigger(TASK_START,port,SITE,stayup);

HideCursor(whichScreen);

%% Experiment Loop
for trial = 1:numel(stimIDs)
    try
        disp(['Start of Trial ' num2str(trial)]); % Output of current trial #

        %% Central fixation interval (jittered 4000 - 6000ms)
        Screen('DrawLines',ptbWindow,fixCoords,stimulus.fixationLineWidth,stimulus.fixationColor,[screenCentreX screenCentreY],2); % Draw fixation cross
        Screen('DrawDots',ptbWindow, backPos, backDiameter, backColor,[],1);
        Screen('Flip', ptbWindow);
        Eyelink('Message', num2str(FIXATION));
        Eyelink('command', 'record_status_message "FIXATION"');
        sendtrigger(FIXATION,port,SITE,stayup);
        timing.cfi(thisTrial) = (randsample(4000:6000, 1))/1000; % Duration of the jittered inter-trial interval
        WaitSecs(timing.cfi(thisTrial));

        %% Presentation of stimulus (5s)

        % Pick .bpm file name from randomized list of all pictures
        stimID(trial) = stimIDs(trial);

        if ismember(stimIDs(trial), tblNF) == 1
            TRIGGER = NF;
            disp(['Positive Stimulus: ' num2str(stimID(trial))])
            data.condition(trial) = 1;
            stimPath = 'fearful';
        elseif ismember(stimIDs(trial), tblNN) == 1
            TRIGGER = NN;
            disp(['Negative Stimulus: ' num2str(stimID(trial))])
            data.condition(trial) = 2;
            stimPath = 'neutral';
        elseif ismember(stimIDs(trial), tblNH) == 1
            TRIGGER = NH;
            disp(['Neutral Stimulus: ' num2str(stimID(trial))])
            data.condition(trial) = 3;
            stimPath = 'happy';
        end

        % Load the movie
        movieFile = sprintf('%s', [FUNS_PATH '/Stimuli/DynamicStimuli/' stimPath '/' stimID(trial) '.mpeg']);
        moviePtr = Screen('OpenMovie', ptbWindow, movieFile);

        % Get the duration of the movie (in seconds)
        movieDuration = Screen('GetMovieTimeIndex', moviePtr);

        % Start playing the movie
        Screen('PlayMovie', moviePtr, 1);

        % Send triggers for presentation
        Eyelink('Message', num2str(PRESENTATION));
        Eyelink('command', 'record_status_message "STIMULUS"');
        sendtrigger(PRESENTATION,port,SITE,stayup);

        % Send triggers for condition
        Eyelink('Message', num2str(TRIGGER));
        Eyelink('command', 'record_status_message "STIMULUS"');
        sendtrigger(TRIGGER,port,SITE,stayup);

        % Wait for the movie to finish
        WaitSecs(movieDuration);

        % Stop playing and close the movie
        Screen('PlayMovie', moviePtr, 0);
        Screen('CloseMovie', moviePtr);

    catch
        psychrethrow(psychlasterror);
    end
end

%% End task, save data and inform participant about accuracy and extra cash

% Send triggers for end of task (ET cutting)
Eyelink('Message', num2str(TASK_END));
Eyelink('command', 'record_status_message "TASK_END"');
sendtrigger(TASK_END,port,SITE,stayup);

% Save data
subjectID = num2str(subject.ID);
filePath = fullfile(DATA_PATH, subjectID);
mkdir(filePath)
fileName = [subjectID '_FAR.mat'];

% Save data
saves = struct;
saves.data = data;
saves.data.stimID = stimID;
saves.experiment = experiment;
saves.screenWidth = screenWidth;
saves.screenHeight = screenHeight;
saves.screenCentreX = screenCentreX;
saves.screenCentreY = screenCentreY;
saves.startExperimentTime = startExperimentTime;
saves.subjectID = subjectID;
saves.subject = subject;
saves.text = text;
saves.timing = timing;
saves.flipInterval = flipInterval;

% Save triggers
trigger = struct;
trigger.FIXATION = FIXATION;
trigger.TASK_START = TASK_START;
trigger.PRESENTATION = PRESENTATION;
trigger.NF = NF;
trigger.NN = NN;
trigger.NH = NH;
trigger.TASK_END = TASK_END;

% Stop and close EEG and ET recordings
disp('SAVING DATA...');
save(fullfile(filePath, fileName), 'saves', 'trigger');
closeEEGandET;

try
    PsychPortAudio('Close');
catch
end

% Quit
Screen('CloseAll');