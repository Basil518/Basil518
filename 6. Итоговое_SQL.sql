 --1     В каких городах больше одного аэропорта?		10
 
select city, count(airport_code) 
from airports a 
group by city
having count(airport_code) > 1      
 

 
-- 2	В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета?	Подзапрос	15
 
select distinct r.departure_airport_name  as airport, t.model, t."range" 
from routes r
join (select a.model, a."range", a.aircraft_code 
	 from aircrafts a 
	 order by a."range" desc 
	 limit 1) as t
on r.aircraft_code = t.aircraft_code
 
select distinct r.arrival_airport_name as airport, t.model, t."range" 
from routes r
join (select a.model, a."range", a.aircraft_code 
	 from aircrafts a 
	 order by a."range" desc 
	 limit 1) as t
on r.aircraft_code = t.aircraft_code

--Логика. Берем аэропорт либо отправления либо прибытия, не существует аэропорта в который прилетают, но не улетают.
--Все рейсы есть туда и обратно в каждом аэропотре. В качестве источника берем представление flights_v так как в нем есть связка "аэропорт - код самолета"

-- 3	Вывести 10 рейсов с максимальным временем задержки вылета	Оператор LIMIT
 
 select flight_no, (actual_departure - scheduled_departure) as "задержка"
 from flights f
 where (actual_departure - scheduled_departure) is not null
 order by  "задержка" desc
 limit 10
 
 --Время задержки равно разнице фактического времени вылета и времени вылета по расписанию.
 --Так как в результате много значений NULL, мешающих сортировке, их убираем.
 
-- 4	Были ли брони, по которым не были получены посадочные талоны?	Верный тип JOIN	
 
select b.book_ref, bp.boarding_no 
from bookings b 
left join tickets t on b.book_ref = t.book_ref 
left join boarding_passes bp on t.ticket_no = bp.ticket_no 
where bp.boarding_no is null 

--Используем left join т.к. необходимо проверить все брони на наличие у них нулевых значений номеров посадочных талонов,
--которые не попадут если использовать inner join.
 
-- 5	Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете.
     -- Добавьте столбец с накопительным итогом - суммарное накопление количества вывезенных пассажиров из каждого аэропорта
     --  на каждый день. Т.е. в этом столбце должна отражаться накопительная сумма - сколько человек уже вылетело из данного
     --  аэропорта на этом или более ранних рейсах в течении дня	Оконная функция; подзапросы или/и cte	35


select f.flight_id, a.airport_name, f.actual_departure :: date,  t.count total_seats, b.count busy_seats,
t.count - b.count as free_seats, round((t.count - b.count)*100/t.count :: numeric, 2),
sum(b.count) over (partition by a.airport_name, f.actual_departure :: date order by b.count)
from flights f
join airports a on f.departure_airport = a.airport_code 
join (
	select f2.flight_id, count(s.seat_no)
	from flights f2 
	join seats s on f2.aircraft_code = s.aircraft_code
	group by f2.flight_id) as t on f.flight_id = t.flight_id
left join (
	select f3.flight_id, count(bp.seat_no) 
	from flights f3 
	join boarding_passes bp  on f3.flight_id  = bp.flight_id
	group by f3.flight_id) as b on f.flight_id = b.flight_id
where f.actual_departure is not null

-- В первом подзапросе формируем общее количество мест в самолете на рейсе,
-- во втором количество занятых мест - колиество выданных посадочных талонов в которых указаны места.
-- Рейсы взяты только те которые фактически вылетели.
-- Одна проблема - на некотые рейсы нет посадочных талонов, хотя они числятся как вылетевшие.
-- Если считать, что самолет улетел пыстым, то на мой взгляд можно оставить и так,
-- если NULL по посадочным талонам имеет другую логику, тогда нужно уточнять запрос. Прошу пояснить.


-- 6	Найдите процентное соотношение перелетов по типам самолетов от общего количества	Подзапрос или окно; оператор ROUND

select  distinct a.model,
count(f.flight_id) over (partition by a.model),
count(f.flight_id) over (),
round (count(f.flight_id) over (partition by a.model)* 100/
count(f.flight_id) over () :: numeric, 2) as percent_flight 
from flights f
join aircrafts a on f.aircraft_code = a.aircraft_code





-- 7	Были ли города, в которые можно добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета?	CTE	25

-- по вылетам
with cte as (
	select distinct fv.flight_id, fv.arrival_city, tf.fare_conditions, tf.amount  
	from flights_v fv
	join ticket_flights tf on fv.flight_id = tf.flight_id
	where tf.fare_conditions = 'Economy'),
cte2 as (
	select distinct fv.flight_id, fv.arrival_city, tf.fare_conditions, tf.amount  
	from flights_v fv
	join ticket_flights tf on fv.flight_id = tf.flight_id
	where tf.fare_conditions = 'Business')
select distinct cte.*, cte2.*,
cte.amount - cte2.amount
from cte 
cross join cte2
where cte.flight_id = cte2.flight_id and cte.amount - cte2.amount > 0

--по рейсам 
with cte as (
	select distinct fv.flight_no, fv.arrival_city, tf.fare_conditions, tf.amount  
	from flights_v fv
	join ticket_flights tf on fv.flight_id = tf.flight_id
	where tf.fare_conditions = 'Economy'),
cte2 as (
	select distinct fv.flight_no, fv.arrival_city, tf.fare_conditions, tf.amount  
	from flights_v fv
	join ticket_flights tf on fv.flight_id = tf.flight_id
	where tf.fare_conditions = 'Business')
select cte.*, cte2.*,
cte.amount - cte2.amount
from cte 
cross join cte2
where cte.flight_no = cte2.flight_no and cte.amount - cte2.amount > 0

 
-- Первым CTE выбираем из представления билеты эконом класса по рейсам в города, вторым CTE билеты бизнес класса,
-- в каждом оставляем только уникальные записи для сокращения количества строк.
-- Далее делаем декартово произведение полученных выборок (каждый с каждым), отсеиваем пересечения с разными городами.
-- вычисляем разницу стоимости билетов эконом минус бизнес
-- и выбираем строки где разница положительная. Прямой ответ на поставленный вопрос получен.
-- Городов куда можно прилететь бизнесом дешевле чем экономом в рамках конкретного перелета нет.
-- В рамках отдельных рейсов независимо от дат таких городов также нет. 


-- 8	Между какими городами нет прямых рейсов?	Декартово произведение в предложении FROM;
--      самостоятельно созданные представления (если облачное подключение, то без представления); оператор EXCEPT	25

create materialized view city as 
	select r.departure_city, r.arrival_city 
	from routes r 
with no data

select a.city, a2.city 
from airports a, airports a2
except
select c.departure_city, c.arrival_city
from city c

--Создаем материализованное представление городов между которыми есть прямые рейсы из существующего представления по маршрутам.
--Далее формируем все возможные сочетание городов - декартово произведение.
--Выитаем из второго множества первое, получаем пары городов между которыми нет прямых рейсов. 

-- 9	Вычислите расстояние между аэропортами, связанными прямыми рейсами, сравните с допустимой максимальной 
--      дальностью перелетов в самолетах, обслуживающих эти рейс*	Оператор RADIANS или использование sind/cosd; CASE