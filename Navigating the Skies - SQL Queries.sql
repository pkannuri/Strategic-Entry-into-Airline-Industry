# Query 1 Airport Rank Hierarchical Structure
WITH RECURSIVE AirportHierarchy AS (
    SELECT Airport_ID, Airport_name, Place, Ranking
    FROM airports
    WHERE Ranking = (SELECT MIN(Ranking) FROM airports)
    UNION ALL
    SELECT a.Airport_ID, a.Airport_name, a.Place, a.Ranking
    FROM airports a
    INNER JOIN AirportHierarchy ah ON a.Ranking = ah.Ranking + 1)
SELECT * FROM AirportHierarchy limit 8;

# Query 2 Top Airports Ranked by Male and Female Literates
SELECT a.Airport_ID, a.Airport_name, a.Place, a.ranking,
(SELECT b.literates_male FROM place b WHERE a.Place = b.city) AS literates_male, 
(SELECT b.literates_female FROM place b WHERE a.Place = b.city) AS literates_female
FROM airports a
ORDER BY literates_male DESC, literates_female DESC
LIMIT 10;

# Query 3 Top 10 Airports by Traffic & Gender Population
SELECT
a.Airport_ID, a.Airport_name, a.Place, a.Passengers_2022_23 as passengertraffic_2022_23,
(SELECT b.population_male FROM place b WHERE a.Place = b.city) AS population_male,
(SELECT b.population_female FROM place b WHERE a.Place = b.city) AS population_female 
FROM airports a
ORDER BY population_male DESC, population_female DESC
LIMIT 10;

# Query 4 Top 5 Destinations from Source Airport
DELIMITER &&
CREATE PROCEDURE TopDestinationFromSource(IN SourceAirportID INT)
BEGIN
    SELECT 
        dest_ap.Airport_name AS Destination_Airport_Name, dest_ap.Place AS Destination_place,
        COUNT(ti.Flight_code) AS NumberOfFlights
    FROM travel_info ti
    INNER JOIN airports dest_ap ON ti.Destination_ID = dest_ap.Airport_ID
    WHERE ti.Source_ID = SourceAirportID
    GROUP BY ti.Destination_ID, dest_ap.Airport_name, dest_ap.Place
    ORDER BY NumberOfFlights DESC
    LIMIT 5;
END &&
DELIMITER ;
CALL TopDestinationFromSource('26434');

# Query 5 Flight Information by Code and Source
DELIMITER &&
CREATE PROCEDURE GetAvgEconomyPrice (IN Flight_Code VARCHAR(10), IN Source_ID INT)
BEGIN
    SELECT a.Airline AS Airline_Name, ap.Airport_name AS Source_Airport_Name, ap.Place AS Source_Place_Name,
        AVG(ti.Economy) AS Average_Economy_Price
    FROM travel_info ti
    INNER JOIN airlines a 
    ON ti.Flight_code = a.Flight_code
    INNER JOIN airports ap 
    ON ti.Source_ID = ap.Airport_ID
    WHERE ti.Flight_code = Flight_Code AND ti.Source_ID = Source_ID
    GROUP BY a.Airline, ap.Airport_name, ap.Place;
END &&
DELIMITER ;
CALL GetAvgEconomyPrice('9I-894', 26618);

# Query 6 Flight Information by Source and Destination IDs
DELIMITER &&
CREATE PROCEDURE GetAirlinesWithPlacesAveragePrice(IN Source_ID INT, IN Destination_ID INT)
BEGIN SELECT a.Airline AS Airline_Name, src_ap.Airport_name AS Source_Airport_Name, src_ap.Place AS Source_Place_Name, dest_ap.Airport_name AS Destination_Airport_Name, dest_ap.Place AS Destination_Place_Name, AVG(ti.Economy) AS Average_Economy_Price
FROM travel_info ti
INNER JOIN airlines a ON ti.Flight_code = a.Flight_code
INNER JOIN airports src_ap ON ti.Source_ID = src_ap.Airport_ID
INNER JOIN airports dest_ap ON ti.Destination_ID = dest_ap.Airport_ID
WHERE ti.Source_ID = Source_ID AND ti.Destination_ID = Destination_ID
GROUP BY a.Airline, src_ap.Airport_name, src_ap.Place, dest_ap.Airport_name, dest_ap.Place;
END && DELIMITER ;

CALL GetAirlinesWithPlacesAveragePrice('35145', '35141');

# Query 7 Airports and their busiest departure times
WITH DepartureArrivalTimes AS ( 
    SELECT a.Airport_name, EXTRACT(HOUR FROM t.Departure_Time) AS DepartureHour, 
        COUNT(*) OVER (PARTITION BY a.Airport_ID, EXTRACT(HOUR FROM t.Departure_Time)) AS DepartureCount, 
        COUNT(*) OVER (PARTITION BY a.Airport_ID, EXTRACT(HOUR FROM t.Arrival_Time)) AS ArrivalCount 
    FROM travel_info t 
    JOIN Airports a ON t.Source_ID = a.Airport_ID OR t.Destination_ID = a.Airport_ID 
), 
RankedDepartureTimes AS ( 
    SELECT Airport_name, DepartureHour, DepartureCount, 
        RANK() OVER (PARTITION BY Airport_name ORDER BY DepartureCount DESC) AS DepartureRank 
    FROM DepartureArrivalTimes 
) 
SELECT DISTINCT d.Airport_name, CONCAT(d.DepartureHour,":00") AS BestDepartureHour 
FROM RankedDepartureTimes d 
WHERE d.DepartureRank = 1 
ORDER BY d.Airport_name; 

# Query 8 Average #Flights Source to Destination on Weekday
WITH DailyFlights AS (
    SELECT DAYNAME(STR_TO_DATE(t.Date_of_journey, '%d-%m-%Y')) AS Weekday, s.Airport_name AS SourceAirport, 
        d.Airport_name AS DestinationAirport, COUNT(*) AS FlightsOnDay
    FROM travel_info t 
    JOIN airports s ON t.Source_ID = s.Airport_ID 
	JOIN airports d ON t.Destination_ID = d.Airport_ID
    GROUP BY Weekday, SourceAirport, DestinationAirport
), 
RankedFlights AS ( SELECT Weekday, SourceAirport, DestinationAirport, AVG(FlightsOnDay) AS AvgFlights,
        RANK() OVER (PARTITION BY Weekday ORDER BY AVG(FlightsOnDay) DESC) AS Day_Rank
    FROM DailyFlights
    GROUP BY Weekday, SourceAirport, DestinationAirport
) 
SELECT Weekday, SourceAirport, DestinationAirport, AvgFlights
FROM RankedFlights
WHERE Day_Rank <= 3 -- Filter to show only top 3 ranks per weekday
ORDER BY Weekday, Day_Rank;

# Query 9 Ranking Airlines by Popularity per Destination
WITH FlightCounts AS (
SELECT a.Airline AS airline, ti.destination_id AS destination, ap.Place, COUNT(*) AS flights_count
FROM travel_Info ti
JOIN airlines a ON ti.flight_code = a.flight_code
JOIN airports ap ON ap.airport_ID = ti.destination_id
GROUP BY a.Airline, ti.destination_id, ap.Place),

RankedAirlines AS 
(SELECT airline, destination, Place, flights_count,
RANK() OVER(PARTITION BY destination ORDER BY flights_count DESC) AS rank_destination
FROM FlightCounts)

SELECT destination, Place, airline, flights_count, rank_destination
FROM RankedAirlines
WHERE rank_destination <= 3;

# Query 10 Airline Ranking by Scheduled Trips per Airport
WITH AirlineFlightCounts AS (
  SELECT ti.Source_ID, a.Airline, COUNT(ti.Flight_code) AS FlightCount, 
	AVG(ti.Economy) AS AvgEconomyPrice
  FROM travel_info ti
  JOIN airlines a ON ti.Flight_code = a.Flight_code
  GROUP BY ti.Source_ID, a.Airline
),
RankedAirlines AS (
  -- Rank airlines by flight count for each airport
  SELECT Source_ID, Airline, FlightCount, AvgEconomyPrice,
    RANK() OVER (PARTITION BY Source_ID ORDER BY FlightCount DESC) AS rank_airline
  FROM AirlineFlightCounts
)
SELECT ra.Source_ID, ap.Airport_name AS Airport_Name, ra.Airline, ra.FlightCount, ra.AvgEconomyPrice, ra.rank_airline
FROM RankedAirlines ra
JOIN airports ap ON ra.Source_ID = ap.Airport_ID
ORDER BY ra.Source_ID, ra.rank_airline;

# Query 11 Analyzing Flight Duration and Pricing Relationship
WITH DurationPricing AS
(  SELECT
    ti.destination_ID,
    AVG(ti.economy) AS average_price,
    AVG(duration_in_mins) AS average_duration
  FROM travel_Info ti
  GROUP BY ti.destination_ID
)
SELECT
dp.destination_ID as Destination_ID, ap.place as Destination, dp.average_price, dp.average_duration
FROM DurationPricing dp
JOIN airports ap
ON ap.airport_ID = dp.destination_id
ORDER BY average_duration DESC;
