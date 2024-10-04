%% Master script for the FaceMorph / FAR (Facial Affect Recognition) project

% - X trials of XXXXX

%% General settings, screens and paths

% Set up MATLAB workspace
clear all;
close all;
clc;
rootFilepath = pwd; % Retrieve the present working directory

% define paths
PPDEV_PATH = '/home/methlab/Documents/MATLAB/ppdev-mex-master'; % for sending EEG triggers
TITTA_PATH = '/home/methlab/Documents/MATLAB/Titta'; % for Tobii ET
DATA_PATH = '/home/methlab/Desktop/FAR/data'; % folder to save data
FUNS_PATH = '/home/methlab/Desktop/FAR' ; % folder with all functions

% make data dir, if doesn't exist yet
mkdir(DATA_PATH)

% add path to folder with functions
addpath(FUNS_PATH)

% manage screens
screenSettings

%% Collect subject infos 
dialogID;

%% Protect Matlab code from participant keyboard input
ListenChar(2);

%% Set up stimuli list
stimIDsetup;
stimIDs = stimIDs(randperm(numel(stimIDs)));

%% Run FAR
FAR;

%% Allow keyboard input into Matlab code
ListenChar(0);