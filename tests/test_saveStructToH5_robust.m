function tests = test_saveStructToH5_robust
tests = functiontests(localfunctions);
end

function testNestedRoundTrip(testCase)
outDir = tempname;
mkdir(outDir);
cleanup = onCleanup(@() rmdir(outDir,'s')); %#ok<NASGU>
fn = fullfile(outDir,'roundtrip.h5');

s = struct();
s.numChannels = 2;
s.frametime = 1/80;
s.alignHz = 80;
s.DSframes = 1:1497;
s.slap2 = struct();
s.slap2.Z_depths = -42.5;
s.slap2.cropRow = 3;
s.slap2.cropCol = 4;
s.slap2.viewC = reshape(1:120,10,12);
s.slap2.viewR = reshape(121:240,10,12);
s.slap2.trimRows = 5:25;
s.slap2.trimCols = 7:30;

saveStructToH5(s,fn);
verifyEqual(testCase,h5read(fn,'/DSframes'),s.DSframes);
verifyEqual(testCase,h5read(fn,'/slap2/viewC'),s.slap2.viewC);
verifyEqual(testCase,h5read(fn,'/slap2/viewR'),s.slap2.viewR);
verifyEqual(testCase,h5read(fn,'/row_major'),uint8(0));
end

function testOverwriteExistingFile(testCase)
outDir = tempname;
mkdir(outDir);
cleanup = onCleanup(@() rmdir(outDir,'s')); %#ok<NASGU>
fn = fullfile(outDir,'overwrite.h5');
s1 = struct('a',1,'b',2);
s2 = struct('a',3,'nested',struct('c',4));
saveStructToH5(s1,fn);
saveStructToH5(s2,fn);
verifyEqual(testCase,h5read(fn,'/a'),3);
verifyEqual(testCase,h5read(fn,'/nested/c'),4);
verifyFalse(testCase,datasetExists(fn,'/b'));
end

function tf = datasetExists(filename,path)
tf = false;
try
    h5info(filename,path);
    tf = true;
catch
end
end
