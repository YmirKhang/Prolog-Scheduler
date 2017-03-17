:- dynamic 
	%to consult from another knowledge base.
	%to use assert, consult and retract for undefined predicates in this kb.
	student/2,
	available_slots/1,
	room_capacity/2.

%Finds all the students and assigns them to a list using built-in finall function.
all_students(StudentList):-
	findall(Name,student(Name,_),StudentList).

%Retrieves all the courses taken from all the students as a list.
all_courses(CourseList):-
	%This finds all the course lists of students and retrieves them in a nested structure.
	findall(Courses,student(_,Courses),NestedCourseList),
	%This flattens the Nested List.
	flatten(NestedCourseList,FlattenedList),
	%Sort simply gets rid of the duplicate values to retrieve a list of unique courses.
	sort(FlattenedList,CourseList).

%This predicate retracts all the predicates that are consulted from another knowledge base.
clear_knowledge_base:-
	% Counts the students in the kb and reports the number of students that has been deleted.
	all_students(StuList),length(StuList,StuCount),write(StuCount),writeln(' students has been deleted'),
	%Does the same for the consulted slots.
	available_slots(Slots),length(Slots,SlotCount),write(SlotCount),writeln(' Slots has been deleted from kb.'),
	%Counts the courses that are going to be retracted.
	all_courses(Courses),length(Courses,CourseCount),write(CourseCount),writeln(' Courses has been deleted from kb'),
	%Does the same for the rooms.	
	findall(Rooms,room_capacity(Rooms,_),Roomslist),length(Roomslist,B),write(B),writeln(' Rooms has been deleted from kb.'),
	%Retracts all the predicates that are consulted to clear cached knowledge base.
	retractall(student(_,_)),
	retractall(room_capacity(_,_)),
	retractall(available_slots(_)).

%Counts the students that take a spesific course.
student_count(CourseId,StudentCount):-
	%finds all the courselist of the students.
	findall(Courses,student(_,Courses),CourseLists),
	%callls the helper predicate to count the students.
	helper(CourseLists,CourseId,StudentCount).

%A helper method which recursively counts all the students take a spesific course.
helper([Clist|CourseLists],CourseId,Count):-
	%retracts the first elememt of the list and goes for recursion
	helper(CourseLists,CourseId,Temp),
	%if the CourseId is in the Courselist of a student increment the count.
	member(CourseId,Clist),
	%Temp is an accumulator.
	Count is Temp+1.

%Keeps the count same if the course is not a member of a courselist of a student.
helper([_|CourseLists],CourseId,Count):-
	helper(CourseLists,CourseId,Temp),
	Count is Temp.
%base case of helper. Empty list has 0 courses taken.
helper([],_,0).


%This predicate calculates the number of students, both taking 2 spesific courses.
common_students(CourseID1,CourseID2,StudentCount):-
	%Finds all the Courselists taken by all students.
	findall(Courses,student(_,Courses),CourseLists),
	%A helper predicate to calclate the count of students who take both of the courses.
	helper2(CourseLists,CourseID1,CourseID2,StudentCount).

%Recursion to find the number of students who take both courses.
helper2([Clist|CourseLists],CourseID1,CourseID2,Count):-
	%Calls the recursion.
	helper2(CourseLists,CourseID1,CourseID2,Temp),
	%If both courses are members of the same students courselist;
	member(CourseID1,Clist),
	member(CourseID2,Clist),
	%Increment the count.
	Count is Temp+1.

%If both courses arent member of a list keep the count same.
helper2([_|CourseLists],CourseID1,CourseID2,Count):-
	helper2(CourseLists,CourseID1,CourseID2,Temp),	
	Count is Temp.

%Base case of the helper2 predicate.
helper2([],_,_,0).


%Calculate a FinalPlan without conflict.

final_plan(FinalPlan):- 
	%Fetches the CourseList to form a FinalPlan accordingly.
	all_courses(CourseList),
	%First call to the recursive scheduler.
	final2(CourseList,FinalPlan,_).

%Recursive predicate for the calculation.

final2([Course|CourseList],[Slot|FinalPlan],[RoomTime|RoomTimeList]):-
	%Recursive call
	final2(CourseList,FinalPlan,RoomTimeList),
	%Checks if the Slot is valid	
	finalSlot(Course,Slot,RoomTime),
	%Checks if the current room and time combination is used before.
	not(member(RoomTime,RoomTimeList)),
	%Checks for the conflicts between finals of the courses.
	isNoConflict(Slot,FinalPlan).	

%Base case for the recursion
final2([],[],[]).
	
%Checks for conflict, true when no conflict.

isNoConflict(Plan,[Compare|FinalPlan]):-
	%Recursive Call
	isNoConflict(Plan,FinalPlan),
	%Compares two slots
	compare(Plan,Compare).

%Base case for recursion.
isNoConflict(_,[]).

%Compares the times of 2 given slots, true when they are different.

compare(Plan,Compare):-
	%Time of the first slot.
	last(Plan,X),
	%Time of the second slot
	last(Compare,Y),
	X\==Y.

%If they are on the same slot checks if there are any common students.

compare([Course1|_],[Course2|_]):-
	%If no common students, 2 slots are valid.
	common_students(Course1,Course2,Count),!,
	Count==0.	

% A predicate helping to put slots according to the courselist.

finalSlot(Course,[Course|Slot],Slot):-
	finalSlot([Course|Slot]).

%Rest is a room and time combination

finalSlot([Course|Rest]):-
	% Checks if rest is a valid room and time combination	
	finalTime(Rest),
	all_courses(CourseList),
	%checks if the course is a valid course.
	member(Course,CourseList),
	%Valid if there is enough space in the room time combination for the course.
	enoughspace(Course,Rest).

%Checks if there is enough space for a course in a given room.

enoughspace(Course,[Room|_]):-
	%Count of the students taking the course.
	student_count(Course,Count),!,
	room_capacity(Room,Size),
	%If room size is bigger than count room is available.
	Size >= Count.

%Arranges a valid room and time combination for a slot

finalTime([Room|[Slot]]):-
	%Fetches the room list
	findall(RoomName,room_capacity(RoomName,_),Roomlist),
	%checks if room is valid
	member(Room,Roomlist),
	%Checks if There is an available slot.
	available_slots(Slots),
	member(Slot,Slots).

%Predicate for counting the errors in a given plan. Driver predicate.

errors_for_plan(FinalPlan,ErrorCount):-
	calculate_errors(FinalPlan,ErrorCount).

%Recursive predicate to count the errors.

calculate_errors([CourseSlot|FinalPlan],ErrorCount):-
	%Recursive Call
	calculate_errors(FinalPlan,Temp),
	%Checks for excess students in a room.
	excess_students(CourseSlot,Excess),
	%Checks the number of students with conflict.
	check_conflict(CourseSlot,FinalPlan,Conflict),
	ErrorCount is Temp + Excess + Conflict.

%Base case

calculate_errors([],0).

%Finds the number of excess students in a slot

excess_students(Slot,ExcessStudents):-
	%Room of the slot
	nth0(1,Slot,Room),
	%Course given to the slot
	nth0(0,Slot,Course),
	room_capacity(Room,Capacity),
	student_count(Course,Students),
	%If students are more than the capacity return the number of excess students.
	Students>Capacity,
	ExcessStudents is Students-Capacity,!.

%Base case

excess_students(_,0).

%Base case for check conflict

check_conflict(_,[],0).

%Recursive predicate for checking conflicts in a given slot and plan.

check_conflict(Slot,[Slot2|Rest],ConflictCount):-
	%recursive call
	check_conflict(Slot,Rest,Temp),
	%Time of the first slot
	nth0(2,Slot,Time),
	%Time of the second slot
	nth0(2,Slot2,Time2),
	%If they are not the same, dont increment.
	Time \== Time2,
	ConflictCount is Temp.

%Second case for the check conflict.
%If times are the same checks for common students

check_conflict(Slot,[Slot2|Rest],ConflictCount):-
	check_conflict(Slot,Rest,Temp),
	nth0(0,Slot,Course),
	nth0(0,Slot2,Course2),
	common_students(Course,Course2,CommonStudents),
	%Adds the number of common students of two courses causing the conflict.
	ConflictCount is Temp + CommonStudents.

%Finito
	
	
	
	


