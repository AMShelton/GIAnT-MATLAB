function tests = test_getOnlineMotion
tests = functiontests(localfunctions);
end

function testFullyVectorizedReader(testCase)
h = MockLineHeaderFileBatch;
lineIds = [1 3 5 8 12 17 23];
[x,y,z] = getOnlineMotion(h,lineIds);
[xe,ye,ze] = expectedOffsets(h,lineIds);
verifyEqual(testCase,x,xe);
verifyEqual(testCase,y,ye);
verifyEqual(testCase,z,ze);
verifyGreaterThan(testCase,h.vectorCalls,0);
verifyEqual(testCase,h.scalarCalls,0);
end

function testCycleGroupedReader(testCase)
h = MockLineHeaderFileGrouped;
lineIds = [1 2 5 7 9 10 17 18];
[x,y,z] = getOnlineMotion(h,lineIds);
[xe,ye,ze] = expectedOffsets(h,lineIds);
verifyEqual(testCase,x,xe);
verifyEqual(testCase,y,ye);
verifyEqual(testCase,z,ze);
verifyGreaterThan(testCase,h.groupedCalls,0);
end

function testScalarFallbackReader(testCase)
h = MockLineHeaderFileScalar;
lineIds = [1 3 5 8 12 17 23];
[x,y,z] = getOnlineMotion(h,lineIds);
[xe,ye,ze] = expectedOffsets(h,lineIds);
verifyEqual(testCase,x,xe);
verifyEqual(testCase,y,ye);
verifyEqual(testCase,z,ze);
verifyEqual(testCase,h.scalarCalls,numel(lineIds));
end

function testInvalidLineIdsRejected(testCase)
h = MockLineHeaderFileBatch;
verifyError(testCase,@() getOnlineMotion(h,0),'getOnlineMotion:InvalidLineIds');
verifyError(testCase,@() getOnlineMotion(h,25),'getOnlineMotion:InvalidLineIds');
verifyError(testCase,@() getOnlineMotion(h,1.5),'getOnlineMotion:InvalidLineIds');
end

function [x,y,z] = expectedOffsets(h,lineIds)
linesPerCycle = numel(h.lineHeaderIdxs);
lineIds = lineIds(:);
cycleIdxs = ceil(lineIds/linesPerCycle);
resIdxs = lineIds-(cycleIdxs-1)*linesPerCycle;
x = double(resIdxs) + 1000*double(cycleIdxs);
y = -double(resIdxs) + 10*double(cycleIdxs);
z = 0.5*double(cycleIdxs);
end
