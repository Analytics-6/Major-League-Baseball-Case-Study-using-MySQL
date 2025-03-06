use maven_advanced_sql

-- PART I: SCHOOL ANALYSIS

-- 1. View the schools and school details tables
select * from schools
select * from school_details

-- 2. In each decade, how many schools were there that produced players?
select count(schoolID) from schools ##17350
select count(distinct schoolID) from schools  ##1038

select floor(yearID/10)*10 as decade, count(distinct schoolID) as num_schools
from schools
group by decade
order by decade

-- 3. What are the names of the top 5 schools that produced the most players?
select * from schools
select * from school_details

select count(playerID) from schools ##17350
select count(distinct playerID) from schools ##6575

select sd.name_full as school_names, count(s.playerID) as num_players
from schools s left join school_details sd
on s.schoolID = sd.schoolID
group by school_names
order by num_players desc
limit 5

select * from
(
select sd.name_full as school_name, count(distinct playerID) as num_players,
       rank() over(order by count(distinct playerID) desc) as rnk
from schools s left join school_details sd
on s.schoolID = sd.schoolID
group by school_name
) x
where x.rnk <=5

with cte as
(
select sd.name_full as school_name, count(distinct playerID) as num_players,
       rank() over(order by count(distinct playerID) desc) as rnk
from schools s left join school_details sd
on s.schoolID = sd.schoolID
group by school_name
)
select *
from cte
where rnk <=5

-- 4. For each decade, what were the names of the top 3 schools that produced the most players?

with ds as
(
select floor(yearID/10)*10 as decade, sd.name_full as school_name, count(distinct playerID) as num_players
from schools s left join school_details sd
on s.schoolID = sd.schoolID
group by decade, school_name
order by decade
),
rn as
(
select decade, school_name, num_players,
       row_number() over(partition by decade order by num_players desc) as row_num
from ds
)
select decade, school_name, num_players from rn
where row_num <= 3
order by decade desc, row_num


-- PART II: SALARY ANALYSIS

-- 1. View the salaries table
select * from salaries

-- 2. Return the top 20% of teams in terms of average annual spending
select yearID, teamID, sum(salary) as total_spend
from salaries
group by yearID, teamID

with ts as
(
select yearID, teamID, sum(salary) as total_spend
from salaries
group by yearID, teamID
),
nt as
(
select teamID, avg(total_spend) as avg_spend,
       ntile(5) over(order by avg(total_spend) desc) as pct
from ts
group by teamID
)
select teamID, round(avg_spend/1000000,1) as avg_spend_millions
from nt
where pct = 1

-- 3. For each team, show the cumulative sum of spending over the years
with ts as
(
select yearID, teamID, sum(salary) as total_spend
from salaries
group by yearID, teamID
),
cs as
(
select YearID, TeamID, total_spend,
       sum(total_spend) over(partition by teamID order by YearID) as cumulative_sum
from ts
)
select YearID, TeamID, round(cumulative_sum/1000000,1) as cumulative_sum_millions
from cs

with ts as
(
select yearID, teamID, sum(salary) as total_spend
from salaries
group by yearID, teamID
)
select YearID, TeamID, total_spend,
       round(sum(total_spend) over(partition by teamID order by YearID)/1000000,1) as cumulative_sum_millions
from ts

-- 4. Return the first year that each team's cumulative spending surpassed 1 billion

with ts as
(
select yearID, teamID, sum(salary) as total_spend
from salaries
group by yearID, teamID
),
cs as
(
select YearID, TeamID, total_spend,
       sum(total_spend) over(partition by teamID order by YearID) as cumulative_sum
from ts
),
bn as
(
select YearID, TeamID, cumulative_sum,
	   row_number() over(partition by teamID order by cumulative_sum) as rn
from cs
where cumulative_sum > 1000000000
)
select YearID, TeamID, round(cumulative_sum/1000000000, 2) as cumulative_sum_billions
from bn
where rn = 1

-- PART III: PLAYER CAREER ANALYSIS

-- 1. View the players table and find the number of players in the table
select * from players

select count(PlayerID) from players #18589
select count(distinct PlayerID) as num_players from players #18589
SELECT COUNT(*) FROM players

-- 2. For each player, calculate their age at their first game, their last game, and their career length (all in years). Sort from longest career to shortest career.
select nameGiven, birthYear, birthMonth, birthDay,debut, finalGame
from players

select nameGiven, 
       concat(birthYear,'-', birthMonth,'-',birthDay) as birthdate,
       timestampdiff(year, cast(concat(birthYear,'-', birthMonth,'-',birthDay)as date), debut) as starting_age,
       timestampdiff(year, cast(concat(birthYear,'-', birthMonth,'-',birthDay) as date), finalGame) as ending_age,
       timestampdiff(year, debut, finalGame) as career_length
from players
order by career_length desc

-- 3. What team did each player play on for their starting and ending years?

select *
from players

select *
from salaries

select playerID, nameGiven
from players

select playerID, yearID, teamID
from salaries

select p.playerID, p.nameGiven, p.debut, p.finalGame,
	   s.yearID as starting_year, s.teamID as starting_team,
       e.yearID as ending_year, e.teamID as ending_team
from players p inner join salaries s
               on p.playerID = s.playerID
               and Year(p.debut) = s.yearID
			  inner join salaries e
              on p.playerID = e.playerID
              and Year(p.finalGame) = e.yearID

-- 4. How many players started and ended on the same team and also played for over a decade?

select p.playerID, p.nameGiven, p.debut, p.finalGame,
	   s.yearID as starting_year, s.teamID as starting_team,
       e.yearID as ending_year, e.teamID as ending_team
from players p inner join salaries s
               on p.playerID = s.playerID
               and Year(p.debut) = s.yearID
			  inner join salaries e
              on p.playerID = e.playerID
              and Year(p.finalGame) = e.yearID
where s.teamID = e.teamID and e.yearID - s.yearID > 10


-- PART IV: PLAYER COMPARISON ANALYSIS
-- 1. View the players table
select * from players

-- 2. Which players have the same birthday?

with bd as
(
select cast(concat(birthYear,'-', birthMonth,'-', birthDay) as date) as birthdate,
       nameGiven
from players
)
select birthdate, group_concat(nameGiven separator ', ') as players, count(nameGiven)
from bd
where year(birthdate) between 1980 and 1990
group by birthdate
order by birthdate

-- 3. Create a summary table that shows for each team, what percent of players bat right, left and both
select s.teamID, 
       round(sum(case when p.bats = 'R' then 1 else 0 end)/count(s.playerID)*100,1) as right_bats,
       round(sum(case when p.bats = 'L' then 1 else 0 end)/count(s.playerID)*100,1) as left_bats,
       round(sum(case when p.bats = 'B' then 1 else 0 end)/count(s.playerID)*100,1) as right_left_bats
from salaries s left join players p
on s.playerID = p.playerID
group by s.teamID


-- 4. How have average height and weight at debut game changed over the years, and what's the decade-over-decade difference?

with hw as
(
select floor(year(debut)/10)*10 as decade, 
round(avg(height),2) as avg_height, 
round(avg(weight),2) as avg_weight
from players
group by decade
)
select decade, 
       avg_height - lag(avg_height) over(order by decade) as height_diff, 
       avg_weight - lag(avg_weight) over(order by decade) as weight_diff
from hw
where decade is not null
