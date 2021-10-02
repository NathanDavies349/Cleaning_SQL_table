SELECT *
FROM Housing..NashvilleHousing

--Update the SaleDate column to be in a useable format (yyy-mm-dd)
SELECT 
	SaleDate
	, CONVERT(Date, SaleDate)
FROM Housing..NashvilleHousing
UPDATE Housing..NashvilleHousing
SET SaleDate = CONVERT(Date, SaleDate)

------------------------------------------------------------------------------------------

--Populating the property address data
--First find any null values, not all address values are filled in
SELECT 
	PropertyAddress
FROM Housing..NashvilleHousing
WHERE PropertyAddress IS NULL
--Now check to see if parcelID corresponds to only 1 address (bar null values)
--Ordering by property address we see that there are several addresses that appear with multiple parcel IDs: likely shared housing/flats
--Produces 50609 rows
SELECT 
	ParcelID
	, PropertyAddress
	, COUNT(PropertyAddress)
FROM Housing..NashvilleHousing
WHERE PropertyAddress IS NOT NULL
GROUP BY ParcelID, PropertyAddress
ORDER BY PropertyAddress

--produces a count of 45068
SELECT 
	COUNT(DISTINCT PropertyAddress)
FROM Housing..NashvilleHousing
WHERE PropertyAddress IS NOT NULL

--produces a count of 48559
SELECT
	COUNT(DISTINCT ParcelID)
FROM Housing..NashvilleHousing
WHERE PropertyAddress IS NOT NULL
--ParcelID count > address count, confirming that multiple parrcel IDs are assigned to the same address on occasion,
--therefore a parcel ID can always be mapped to an address but an address cannot always be mapped to a single parcelID
--Will populate null addresses with addresses from corresponding parcelIDs.

--Join table onto itself to find all matching parcelIDs and then populate those with null addresses
SELECT 
	a.ParcelID AS [ParcelID a]
	, a.PropertyAddress AS [PropertyAddress a]
	, b.ParcelID AS [ParcelID b]
	, b.PropertyAddress AS [PropertyAddress b]
	, ISNULL(a.PropertyAddress, b.PropertyAddress) AS [ISNULL populating]
FROM Housing..NashvilleHousing a
JOIN Housing..NashvilleHousing b
	ON a.ParcelID = b.ParcelID --ParcelIDs must match
	AND a.[UniqueID ] <> b.[UniqueID ] --Must have a different UniqueID so that we can access the non null addresses
WHERE a.PropertyAddress IS NULL --Only care for the null addresses

UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM Housing..NashvilleHousing a
JOIN Housing..NashvilleHousing b
	ON a.ParcelID = b.ParcelID --ParcelIDs must match
	AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress IS NULL
--After executing the UPDATE there are no longer any null addresses present

------------------------------------------------------------------------------------------

--Populating the owner details
--First find any null values, not all owner details are filled in
SELECT 
	ParcelID
	, OwnerName
	, OwnerAddress
FROM Housing..NashvilleHousing
ORDER BY ParcelID

--attempt to match any owner names/addresses to other rows in the tables that share a parcel ID for the property but with a different unique ID
SELECT 
	a.ParcelID AS [ParcelID a]
	, a.OwnerName AS [OwnerName a]
	, a.OwnerAddress AS [OwnerAddress a]
	, b.ParcelID AS [ParcelID b]
	, b.OwnerName AS [OwnerName b]
	, b.OwnerAddress AS [OwnerAddress b]
	, ISNULL(a.OwnerName, b.OwnerName) AS [ISNULL OwnerName]
	, ISNULL(a.OwnerAddress, b.OwnerAddress) AS [ISNULL OwnerAddress]
FROM Housing..NashvilleHousing a
JOIN Housing..NashvilleHousing b
	ON a.ParcelID = b.ParcelID --ParcelIDs must match
	AND a.[UniqueID ] <> b.[UniqueID ] --Must have a different UniqueID so that we can access the non null data
WHERE a.OwnerAddress IS NULL --Only care for the null addresses (or owner names)
--none of these can have the missing data filled in in the same way as the property address, all missing owner names and addresses remain as null values

------------------------------------------------------------------------------------------

--Splitting the address out for each of address, city and state (delimiter of ',')
SELECT
	SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress)-1) AS Address --'-1' is to remove the comma from the address output
	, SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress)+1, LEN(PropertyAddress)) AS City --'+1' is to start the string after the comma so it does not appear in the city name
FROM Housing..NashvilleHousing

ALTER TABLE Housing..NashvilleHousing
ADD PropertySplitAddress NVARCHAR(255)
UPDATE Housing..NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress)-1)

ALTER TABLE Housing..NashvilleHousing
ADD PropertySplitCity NVARCHAR(255)
UPDATE Housing..NashvilleHousing
SET PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress)+1, LEN(PropertyAddress))



--Alternate method for address splitting performed on owner address
SELECT OwnerAddress
FROM Housing..NashvilleHousing

SELECT
--PARSENAME finds '.' from the end to the beginning i.e. back-to-front
	PARSENAME(REPLACE(OwnerAddress,',','.'),3)--PARSENAME requires '.' in the string so need to replace ',' with '.' to split up the address
	, PARSENAME(REPLACE(OwnerAddress,',','.'),2)
	, PARSENAME(REPLACE(OwnerAddress,',','.'),1)
FROM Housing..NashvilleHousing



ALTER TABLE Housing..NashvilleHousing
ADD OwnerSplitAddress NVARCHAR(255),
	OwnerSplitCity NVARCHAR(255),
	OwnerSplitState NVARCHAR(255);

UPDATE Housing..NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress,',','.'),3)
UPDATE Housing..NashvilleHousing
SET OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress,',','.'),2)
UPDATE Housing..NashvilleHousing
SET OwnerSplitState = PARSENAME(REPLACE(OwnerAddress,',','.'),1)

------------------------------------------------------------------------------------------

--In 'SoldAsVacant' change all y and n to Yes and No

SELECT DISTINCT(SoldAsVacant), COUNT(SoldAsVacant)
FROM Housing..NashvilleHousing
GROUP BY SoldAsVacant
ORDER BY 2
--shows that values are only y, n, Yes or No and Yes and No are the most populated values

UPDATE Housing..NashvilleHousing
SET SoldAsVacant = CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
						WHEN SoldAsVacant = 'N' THEN 'No'
						ELSE SoldAsVacant
						END
--Now all values are either Yes or No

------------------------------------------------------------------------------------------

--Identifying duplicate rows, can create a view or temp table without them present instead of deleting from the main table
WITH RowCountCTE AS(
SELECT *
	, ROW_NUMBER() OVER (PARTITION BY ParcelID,
						PropertyAddress,
						SaleDate,
						SalePrice,
						LegalReference,
						OwnerAddress
						ORDER BY UniqueID
						) AS [Row Count]
FROM Housing..NashvilleHousing
)
SELECT *
FROM RowCountCTE
--WHERE [Row Count] > 1 --to only use duplicates use this
WHERE [Row Count] = 1 --to use all non-duplicates use this
ORDER BY ParcelID