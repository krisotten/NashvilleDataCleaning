-- DATA CLEANING NASHVILLE HOUSING DATA 
-----------------------------------------------------------------------------

-- STANDARDIZE DATE FORMAT
-- We are mainly interested in the date of the sale, not the time it took place. We can simplify the data by converting the data type for SaleDate to DATE rather than DATETIME

-- Create new column for converted dates 
ALTER TABLE PortfolioProject..NashvilleHousing
ADD SaleDateConverted DATE

-- Update new column with each SaleDate converted to a date 
UPDATE PortfolioProject..NashvilleHousing
SET SaleDateConverted = CONVERT(DATE, SaleDate)

-- Display results to ensure accuracy
SELECT SaleDate, SaleDateConverted
FROM PortfolioProject..NashvilleHousing

-----------------------------------------------------------------------------

-- POPULATE PROPERTY ADDRESS DATA
-- Some rows have null values for property address and we want to avoid this. In the data, rows sharing the same ParcelID also share the same Property Address, so we can use ParcelID to identify the correct PropertyAddress and fill in the null values.

SELECT *
FROM PortfolioProject..NashvilleHousing
-- WHERE PropertyAddress IS NULL
ORDER BY ParcelID

-- Locate rows where PropertyAddress is NULL and find all rows matching those ParcelIDs
SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM PortfolioProject..NashvilleHousing a
JOIN PortfolioProject..NashvilleHousing b 
    ON a.ParcelID = b.ParcelID
    AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress IS NULL

-- Update the NULL values of PropertyAddress with the value for PropertyAddress in the row matching ParcelID
UPDATE a 
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM PortfolioProject..NashvilleHousing a
JOIN PortfolioProject..NashvilleHousing b 
    ON a.ParcelID = b.ParcelID
    AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress IS NULL

-----------------------------------------------------------------------------

-- BREAKING UP ADDRESS INTO SEPARATE COLUMNS (Address, City, State) 

-- METHOD 1: Using SUBSTRING for PropertyAddress

-- Add new column for address without city or state
ALTER TABLE PortfolioProject..NashvilleHousing
ADD PropertySplitAddress NVARCHAR(255)

-- Update new address column by taking a substring of PropertyAddress starting at position 1 and ending at the position of the comma (minus 1 as not to include the comma)
UPDATE PortfolioProject..NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress) - 1) AS Address

-- Add new column for city
ALTER TABLE PortfolioProject..NashvilleHousing
ADD PropertySplitCity NVARCHAR(255)

-- Update city column by taking a substring of PropertyAddress starting at the position of the comma and ending at the length of property address
UPDATE PortfolioProject..NashvilleHousing
SET PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) + 1, LEN(PropertyAddress)) AS City

-- METHOD 2: Using PARSENAME for OwnerAddress

-- Replace the commas in OwnerAddress with periods to work with the PARSENAME function 
-- Return results to ensure accuracy before creating and populating new columns 
SELECT 
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3)
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2)
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)
FROM PortfolioProject..NashvilleHousing

-- Add new column for address without city or state 
ALTER TABLE PortfolioProject..NashvilleHousing
ADD OwnerSplitAddress NVARCHAR(255)

-- Update new address column with results from PARSENAME 
UPDATE PortfolioProject..NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3)

-- Add new column for city 
ALTER TABLE PortfolioProject..NashvilleHousing
ADD OwnerSplitCity NVARCHAR(255)

-- Update new city column with results from PARSENAME 
UPDATE PortfolioProject..NashvilleHousing
SET OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2)

-- Add new column for state 
ALTER TABLE PortfolioProject..NashvilleHousing
ADD OwnerSplitState NVARCHAR(255)

-- Update new state column with results from PARSENAME 
UPDATE PortfolioProject..NashvilleHousing
SET OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)

-- Output results to ensure accuracy 
SELECT OwnerSplitAddress, OwnerSplitCity, OwnerSplitState
FROM PortfolioProject..NashvilleHousing

-----------------------------------------------------------------------------

-- FORMATTING "SOLD AS VACANT" FIELD 

-- Return current values in SoldAsVacant column. We want to make these results consistent by changing Y and N to Yes and No 
SELECT DISTINCT(SoldAsVacant), COUNT(SoldAsVacant)
FROM PortfolioProject..NashvilleHousing
GROUP BY SoldAsVacant
ORDER BY 2

-- Return current values of SoldAsVacant and replaced values 
SELECT SoldAsVacant,
CASE WHEN SoldAsVacant = 'Y' THEN 'Yes' 
WHEN SoldAsVacant = 'N' THEN 'No'
ELSE SoldAsVacant
END
FROM PortfolioProject..NashvilleHousing 

-- Update SoldAsVacant column so all Y and N values are replaced with Yes and No 
UPDATE PortfolioProject..NashvilleHousing
SET SoldAsVacant = CASE WHEN SoldAsVacant = 'Y' THEN 'Yes' 
WHEN SoldAsVacant = 'N' THEN 'No'
ELSE SoldAsVacant
END

-----------------------------------------------------------------------------

-- REMOVE DUPLICATES 

-- The RowNumCTE uses the ROW_NUMBER() function to count duplicates by partitioning by multiple columns that duplicates will share the value of.
-- Once row_num has been assigned for each row, the query following the CTE selects duplicates by checking when row_num is greater than 1. 
WITH RowNumCTE AS (
SELECT *,
ROW_NUMBER() OVER (
    PARTITION BY ParcelID,
    PropertyAddress,
    SalePrice,
    SaleDate,
    LegalReference
    ORDER BY UniqueID 
) row_num
FROM PortfolioProject..NashvilleHousing
)
SELECT * 
FROM RowNumCTE
WHERE row_num > 1
ORDER BY PropertyAddress

-- Delete duplicates using the same CTE. Rerun the previous query to ensure that no duplicates remain (0 results)
WITH RowNumCTE AS (
SELECT *,
ROW_NUMBER() OVER (
    PARTITION BY ParcelID,
    PropertyAddress,
    SalePrice,
    SaleDate,
    LegalReference
    ORDER BY UniqueID 
) row_num
FROM PortfolioProject..NashvilleHousing
)
DELETE 
FROM RowNumCTE
WHERE row_num > 1

-----------------------------------------------------------------------------

-- DELETE UNUSED COLUMNS 

-- We've already created new columns for address, city, and state for both PropertyAddress and OwnerAddress so we can delete PropertyAddress and OwnerAddress 
ALTER TABLE PortfolioProject..NashvilleHousing
DROP COLUMN OwnerAddress, TaxDistrict, PropertyAddress

-- We've already converted SaleDate to a date type in SaleDateConverted so we can delete SaleDate
ALTER TABLE PortfolioProject..NashvilleHousing
DROP COLUMN SaleDate
