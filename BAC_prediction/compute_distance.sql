----------------------------------------
--- ADD AVERAGE DISTANCE TRAVELED BETWEEN SUBSEQUENT POINTS ---
----------------------------------------

-- https://stackoverflow.com/questions/19412462/getting-distance-between-two-points-based-on-latitude-longitude

-- approximate radius of earth in km
-- R = 6373.0

-- lat1 = radians(52.2296756)
-- lon1 = radians(21.0122287)
-- lat2 = radians(52.406374)
-- lon2 = radians(16.9251681)

-- dlon = lon2 - lon1
-- dlat = lat2 - lat1

-- a = sin(dlat / 2)**2 + cos(lat1) * cos(lat2) * sin(dlon / 2)**2
-- c = 2 * atan2(sqrt(a), sqrt(1 - a))

-- distance = R * c

-- print("Result:", distance)
-- print("Should be:", 278.546, "km")

-- ----------------------------------------
-- -- VALIDATE CODE

DROP TABLE IF EXISTS radians;
CREATE TEMP TABLE radians (
	lat1 float8, 
	lon1 float8, 
	lat2 float8, 
	lon2 float8, 
	dlat float8, 
	dlon float8
);

INSERT INTO radians (lat1, lon1, lat2, lon2) VALUES (52.2296756, 21.0122287, 52.406374, 16.9251681);-- 278.545589351 km.
-- INSERT INTO radians (lat1, lon1, lat2, lon2) VALUES (30.46847, -97.84808, 30.48621, -97.84254);-- 2.04343403613478

UPDATE radians SET lat1 = RADIANS(lat1);
UPDATE radians SET lon1 = RADIANS(lon1);
UPDATE radians SET lat2 = RADIANS(lat2);
UPDATE radians SET lon2 = RADIANS(lon2);



UPDATE radians SET dlon = lon2 - lon1;
UPDATE radians SET dlat = lat2 - lat1;

ALTER TABLE radians ADD COLUMN a float8;
ALTER TABLE radians ADD COLUMN c float8;
UPDATE radians SET a = (sin(dlat / 2)*sin(dlat / 2)) + cos(lat1) * cos(lat2) * (sin(dlon / 2)*sin(dlon / 2));
UPDATE radians SET c = 2 * atan2(sqrt(a), sqrt(1 - a));

ALTER TABLE radians ADD COLUMN distance float8;
UPDATE radians SET distance = 6373.0 * c;

SELECT distance FROM radians AS km;
-- -- The distance is now returning the correct value of 278.545589351 km.
-- -- yeah! works now


----------------------------
--- APPLY TO BAC GEODATA ---
----------------------------

-- I'm starting with an existing table called bac.final_analysis5
-- Note: when lat and lon are both 0, which happens in this dataset probably due to technical errors,
-- distance and all derivative variables are incorrect; hence, I've coded accordingly.


-----------------------------
-- ADD LATITUDE & LONGITUDE --> CALCULATE LAGS (PRIOR LAT LON VALUES) FOR DISTANCE CALCULATION

-- latitude:  (10-14-2017 added where clause to inner select)
ALTER TABLE bac.final_analysis5 ADD COLUMN lat_lag float8;
UPDATE bac.final_analysis5 SET lat_lag = b.lat_lag 
	FROM bac.final_analysis5 a 
		JOIN (SELECT username, timestamp_gmt, LAG(latitude, 1) OVER (PARTITION BY username ORDER BY timestamp_gmt) AS lat_lag
			FROM bac.final_analysis5 WHERE latitude<>0 and longitude<>0) b 
		ON a.username=b.username AND a.timestamp_gmt=b.timestamp_gmt;

-- longitude
ALTER TABLE bac.final_analysis5 ADD COLUMN lon_lag float8;
UPDATE bac.final_analysis5 SET lon_lag = b.lon_lag 
	FROM bac.final_analysis5 a 
		JOIN (SELECT username, timestamp_gmt, LAG(longitude, 1) OVER (PARTITION BY username ORDER BY timestamp_gmt) AS lon_lag
			FROM bac.final_analysis5 WHERE latitude<>0 and longitude<>0) b 
		ON a.username=b.username AND a.timestamp_gmt=b.timestamp_gmt;

-- QA
SELECT username, timestamp_converted_to_local, latitude, longitude, lat_lag, lon_lag
FROM bac.final_analysis5 ORDER BY 1,2 LIMIT 10;


-------------------
---

ALTER TABLE bac.final_analysis5 ADD COLUMN lat1 float8;
ALTER TABLE bac.final_analysis5 ADD COLUMN lon1 float8;
ALTER TABLE bac.final_analysis5 ADD COLUMN lat2 float8;
ALTER TABLE bac.final_analysis5 ADD COLUMN lon2 float8;

UPDATE bac.final_analysis5 SET lat1 = RADIANS(latitude);
UPDATE bac.final_analysis5 SET lon1 = RADIANS(longitude);
UPDATE bac.final_analysis5 SET lat2 = RADIANS(lat_lag);
UPDATE bac.final_analysis5 SET lon2 = RADIANS(lon_lag);

ALTER TABLE bac.final_analysis5 ADD COLUMN dlat float8;
ALTER TABLE bac.final_analysis5 ADD COLUMN dlon float8;
UPDATE bac.final_analysis5 SET dlon = lon2 - lon1;
UPDATE bac.final_analysis5 SET dlat = lat2 - lat1;


ALTER TABLE bac.final_analysis5 ADD COLUMN a float8;
ALTER TABLE bac.final_analysis5 ADD COLUMN c float8;
UPDATE bac.final_analysis5 SET a = (sin(dlat / 2)*sin(dlat / 2)) + cos(lat1) * cos(lat2) * (sin(dlon / 2)*sin(dlon / 2));
UPDATE bac.final_analysis5 SET c = 2 * atan2(sqrt(a), sqrt(1 - a));

ALTER TABLE bac.final_analysis5 ADD COLUMN distance_km float8;
UPDATE bac.final_analysis5 SET distance_km = 6373.0 * c;

-- QA
SELECT username, timestamp_converted_to_local, latitude, longitude, lat_lag, lon_lag, dlat, dlon, distance_km
FROM bac.final_analysis5 ORDER BY 1,2 LIMIT 10;

-- Go back and use some of the datapoints from this dataset, test them in the toy example to verify the answer for distance
-- Did it, works!

-- drop unnecessary columns
ALTER TABLE bac.final_analysis5 DROP COLUMN lat1;
ALTER TABLE bac.final_analysis5 DROP COLUMN lon1;
ALTER TABLE bac.final_analysis5 DROP COLUMN lat2;
ALTER TABLE bac.final_analysis5 DROP COLUMN lon2;
ALTER TABLE bac.final_analysis5 DROP COLUMN lat_lag;
ALTER TABLE bac.final_analysis5 DROP COLUMN lon_lag;
ALTER TABLE bac.final_analysis5 DROP COLUMN dlat;
ALTER TABLE bac.final_analysis5 DROP COLUMN dlon;
ALTER TABLE bac.final_analysis5 DROP COLUMN a;
ALTER TABLE bac.final_analysis5 DROP COLUMN c;

-- FINAL LENGTH QA
SELECT COUNT(*) FROM bac.final_analysis5;--973264