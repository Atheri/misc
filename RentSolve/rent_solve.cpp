#include <iostream>
#include <fstream>
#include <iomanip>
using namespace std;

int main() {
    int res_x = 3;
    int res_y = 2;
    int rent_x;
    int rent_y;
    int rent = 1380;

    ofstream myout;
    myout.open("rent.out");
    myout << "Rent " << rent << " between " << res_x << " and " << res_y << endl;
    myout << "--------------------------------------------" << endl;
    myout << res_x << " " << res_y << endl;

    int base = 10;
    int n = rent;
    int out_width = 0;
    while (n > 0) {
        ++out_width; 
        n = n/base;
    }
    
    int ratio_x, ratio_y;
    for (rent_x = 0; rent_x < rent+1; ++rent_x) {
        for (rent_y = 0; rent_y < rent+1; ++rent_y) {
            if (rent_x*res_x + rent_y*res_y == rent) {
                ratio_x = (rent_x*100)/rent;
                ratio_y = (rent_y*100)/rent;
                myout << left 
                      << setw(4) << ratio_x << setw(out_width+1) << rent_x 
                      << setw(4) << ratio_y << rent_y << endl;   
            }
        }
    }

}
