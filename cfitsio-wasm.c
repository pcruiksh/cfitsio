#include "fitsio.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int write_fits(const char* filename, int bitpix, long* naxes, int naxis, void* data) {
    fitsfile *fptr;
    int status = 0;

    // Create new FITS file (overwrite if exists)
    fits_create_file(&fptr, filename, &status);
    if (status != 0) return status;

    // Create the primary array image (2D, 3D, etc.)
    fits_create_img(fptr, bitpix, naxis, naxes, &status);
    if (status != 0) {
        fits_close_file(fptr, &status);
        return status;
    }

    // Write the image data (assume 1-based indexing for FITS)
    long fpixel = 1;
    long nelements = 1;
    for (int i = 0; i < naxis; ++i) nelements *= naxes[i];

    // Map bitpix to data type for fits_write_img
    int datatype;
    switch (bitpix) {
        case 8:   datatype = 11; break;  // BYTE_IMG -> TBYTE
        case 16:  datatype = 21; break;  // SHORT_IMG -> TSHORT  
        case 32:  datatype = 31; break;  // LONG_IMG -> TINT
        case 64:  datatype = 81; break;  // LONGLONG_IMG -> TLONGLONG
        case -32: datatype = 42; break;  // FLOAT_IMG -> TFLOAT
        case -64: datatype = 82; break;  // DOUBLE_IMG -> TDOUBLE
        case 10:  datatype = 12; break;  // SBYTE_IMG -> TSBYTE
        case 20:  datatype = 20; break;  // USHORT_IMG -> TUSHORT
        case 40:  datatype = 30; break;  // ULONG_IMG -> TUINT
        case 80:  datatype = 80; break;  // ULONGLONG_IMG -> TULONGLONG
        default:  
            fits_close_file(fptr, &status);
            return -1; // Unsupported bitpix
    }

    fits_write_img(fptr, datatype, fpixel, nelements, data, &status);
    if (status != 0) {
        fits_close_file(fptr, &status);
        return status;
    }

    fits_close_file(fptr, &status);
    return status;
}

// Read a file from the virtual filesystem and return pointer to its contents
// Returns NULL if file doesn't exist or on error
// The caller is responsible for freeing the returned memory with free()
// file_size_out will contain the size of the file in bytes
unsigned char* read_file_data(const char* filename, long* file_size_out) {
    FILE* file = fopen(filename, "rb");
    if (!file) {
        if (file_size_out) *file_size_out = -1; // Error indicator
        return NULL;
    }

    // Get file size
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    if (file_size <= 0) {
        fclose(file);
        if (file_size_out) *file_size_out = -1;
        return NULL;
    }

    // Allocate memory for file contents
    unsigned char* buffer = (unsigned char*)malloc(file_size);
    if (!buffer) {
        fclose(file);
        if (file_size_out) *file_size_out = -1;
        return NULL;
    }

    // Read file contents
    size_t bytes_read = fread(buffer, 1, file_size, file);
    fclose(file);

    if (bytes_read != (size_t)file_size) {
        free(buffer);
        if (file_size_out) *file_size_out = -1;
        return NULL;
    }

    if (file_size_out) *file_size_out = file_size;
    return buffer;
}

// Check if a file exists in the virtual filesystem
int file_exists(const char* filename) {
    FILE* file = fopen(filename, "rb");
    if (file) {
        fclose(file);
        return 1; // File exists
    }
    return 0; // File doesn't exist
}

// Delete a file from the virtual filesystem
int delete_file(const char* filename) {
    return remove(filename);
}