--What is hitting the data dictionary?
Select Upper(Parameter) Parameter,
Gets,
Getmisses,
(Decode(Gets,0,1,Gets)-Getmisses)
*100/Decode(Gets,0,1,Gets) "HIT %",
Count,
Usage
From V$RowCache;