#include <iostream>
#include <bitset>
#include <vector>
#include <fstream>
#include <unordered_map>
#include <string>
#include <sstream>
#include <math.h>
#include <stdio.h>
#include <exception>
#include <set>
#include <stdint.h>

const std::size_t ROM_SIZE = std::pow(2, 9);
const std::size_t ROM_CMD = 28;
using bit_cmd = std::bitset<ROM_CMD>;

std::string to_hex_string(const bit_cmd& _cmd) {
    const std::size_t num_bits = _cmd.size();
    char* hex_str = new char[num_bits/4 + 1];
    std::size_t s = 0;
    hex_str[num_bits/4] = '\0';

    for (std::size_t i = 0; i < num_bits; i += 4) {
        std::size_t b = 0;
        for (std::size_t j = 0; j < 4; j++) {
            int v = num_bits - i - j - 1;
            b += _cmd[num_bits - i - j - 1] << 3 - j;
        }
        if (0 <= b && 9 >= b)
            hex_str[s++] = static_cast<char>(b) + '0';
        else if (10 <= b && 15 >= b)
            hex_str[s++] = static_cast<char>(b - 10) + 'a';
    }

    std::string hex_string(hex_str);
    delete[] hex_str;
    return hex_string;
}

const std::unordered_map<std::string, unsigned short> cmd = {
    {"cmp", 0x0}, // compare 2 register:                                         cmp rga rgb
    {"mov", 0x1}, // move data from second register to first:                    mov rga rgb 
    {"and", 0x2}, // bitwise AND. result saved on rgk:                           and rga rgb
    {"or",  0x3}, // bitwise OR. result saved on rgk:                            or  rga rgb
    {"not", 0x4}, // bitwise NOT. result saved on rgk:                           not rga rgb
    {"xor", 0x5}, // bitwise XOR. result saved on rgk:                           xor rga rgb
    {"add", 0x6}, // sum 2 register. result saved on rgk. rga + rgb = rgk:       add rga rgb
    {"sub", 0x7}, // subtract 2 register. result saved on rgk. rga - rgb = rgk:  sub rga rgb
    {"rom", 0x8}, // set rom channel:                                            rom 0x4
    {"inp", 0x9}, // save input value to selected resiter:                       inp 0xF rga // input value saved on rga
    {"fin", 0xA}, // set ready out flag:                                         fin
    {"err", 0xB}, // set error code:                                             err 0x1
    {"shr", 0xC}, // right bitwise shift for selected register:                  shr rga
    {"shl", 0xD}, // left bitwise shift for selected register:                   shl rga
    {"brk", 0xE}, // breakpoint. breakpoint input should be 1 to continue        brk

    {"jmp", 0x10}, // always
    {"jne", 0x11}, // if not equal
    {"jme", 0x12}, // if equal
    {"jml", 0x13}, // if less
    {"jmo", 0x14}, // overflow exception
};
const std::unordered_map<std::string, unsigned short> wire = {
    {"rga", 0x0},
    {"rgb", 0x1},
    {"rgc", 0x2},
    {"rgd", 0x3},
    {"rge", 0x4},
    {"rgf", 0x5},
    // {"rgg", 0x6},

    {"rgk", 0xD},
    {"rmv", 0xE},
    {"inp", 0xF}
};
std::unordered_map<std::string, std::size_t> jmp_address;

std::size_t command_line = 0;
std::size_t all_line = 0;
bit_cmd line = {};

void parse_file(std::string input) {
    // delete comment
    std::size_t comment_pos = input.find("//");
    std::string l = (comment_pos != std::string::npos) ? input.substr(0, comment_pos) : input;
    
    if (l.find(":") != std::string::npos) {
        std::istringstream stream(l);
        std::string word;
        stream >> word;
        std::string jump_line = word.substr(0, word.find(":"));
        jmp_address.insert({ jump_line, command_line });
        return;
    }

    std::istringstream stream(l);
    std::string word;
    stream >> word;
    if (cmd.end() != cmd.find(word))
        command_line++;
    return;
}
bool readline(std::string input) {
    // reset line
    line = {};
    all_line++;

    // delete comment
    std::size_t comment_pos = input.find("//");
    std::string l = (comment_pos != std::string::npos) ? input.substr(0, comment_pos) : input;
    // jump block
    if (l.find(":") != std::string::npos) {
        return false;
    }

    // parse line without comment
    std::istringstream stream(l);
    std::vector<std::string> result;
    std::string word;
    while (stream >> word) result.push_back(word);

    if (!result.size()) return false;
    if (result.size() > 3) 
        throw std::invalid_argument("too much argument on line " + input);

    while (result.size() != 3) result.push_back("0x0");

    // assembly bitset
    std::unordered_map<std::string, unsigned short>::const_iterator iter_cmd = cmd.find(result[0]);
    if (cmd.end() == iter_cmd)
        throw std::invalid_argument("undefined operator: " + result[0] + " on line " + std::to_string(all_line));
    unsigned short cmd_num = iter_cmd->second;

    if (0x0 <= cmd_num && 0xF >= cmd_num) {
        std::unordered_map<std::string, unsigned short>::const_iterator iter1 = wire.find(result[1]);
        std::unordered_map<std::string, unsigned short>::const_iterator iter2 = wire.find(result[2]);
        unsigned short wire1_num;
        unsigned short wire2_num;
        if (wire.end() != iter1) wire1_num = (*iter1).second;
        else wire1_num = std::stoi(result[1], nullptr, 16);
        if (wire.end() != iter2) wire2_num = (*iter2).second;
        else wire2_num = std::stoi(result[2], nullptr, 16);

        // set cmd
        line[line.size() - 1]  = cmd_num   & 0x08ui16;
        line[line.size() - 2]  = cmd_num   & 0x04ui16;
        line[line.size() - 3]  = cmd_num   & 0x02ui16;
        line[line.size() - 4]  = cmd_num   & 0x01ui16;

        // set wire1_ctrl
        line[line.size() - 5]  = wire1_num & 0x08ui16;
        line[line.size() - 6]  = wire1_num & 0x04ui16;
        line[line.size() - 7]  = wire1_num & 0x02ui16;
        line[line.size() - 8]  = wire1_num & 0x01ui16;

        // set wire2_ctrl
        line[line.size() - 9]  = wire2_num & 0x08ui16;
        line[line.size() - 10] = wire2_num & 0x04ui16;
        line[line.size() - 11] = wire2_num & 0x02ui16;
        line[line.size() - 12] = wire2_num & 0x01ui16;

        if (0x9 == cmd_num) {
            // waiting for a sign RI
            line[line.size() - 13] = 0;
            line[line.size() - 14] = 0;
            line[line.size() - 15] = 1;

            // set E
            line[line.size() - 16] = 1;
        }
        if (0xA == cmd_num) {
            // set E
            line[line.size() - 16] = 1;
        }
        if (0xE == cmd_num) {
            // waiting for a sign BREAKPOINT
            line[line.size() - 13] = 1;
            line[line.size() - 14] = 1;
            line[line.size() - 15] = 0;

            // set E
            line[line.size() - 16] = 1;
        }

        // set current command
        line[line.size() - 17] = command_line & 0x800ui16;
        line[line.size() - 18] = command_line & 0x400ui16;
        line[line.size() - 19] = command_line & 0x200ui16;
        line[line.size() - 20] = command_line & 0x100ui16;
        line[line.size() - 21] = command_line & 0x080ui16;
        line[line.size() - 22] = command_line & 0x040ui16;
        line[line.size() - 23] = command_line & 0x020ui16;
        line[line.size() - 24] = command_line & 0x010ui16;
        line[line.size() - 25] = command_line & 0x008ui16;
        line[line.size() - 26] = command_line & 0x004ui16;
        line[line.size() - 27] = command_line & 0x002ui16;
        line[line.size() - 28] = command_line & 0x001ui16;

        command_line++;
    }
    if (0x10 <= cmd_num && 0x14 >= cmd_num) {
        // set cmd
        line[line.size() - 1] = 1;
        line[line.size() - 2] = 1;
        line[line.size() - 3] = 1;
        line[line.size() - 4] = 1;

        // set wire1_ctrl
        line[line.size() - 5] = 0;
        line[line.size() - 6] = 0;
        line[line.size() - 7] = 0;
        line[line.size() - 8] = 0;

        // set wire2_ctrl
        line[line.size() - 9]  = 0;
        line[line.size() - 10] = 0;
        line[line.size() - 11] = 0;
        line[line.size() - 12] = 0;

        if (0x10 == cmd_num) {
            // void sign
            line[line.size() - 13] = 0;
            line[line.size() - 14] = 0;
            line[line.size() - 15] = 0;

            // set E
            line[line.size() - 16] = 1;
        }
        if (0x11 == cmd_num) {
            // PNEQUAL sign
            line[line.size() - 13] = 0;
            line[line.size() - 14] = 1;
            line[line.size() - 15] = 0;
        }
        if (0x12 == cmd_num) {
            // PEQUAL sign
            line[line.size() - 13] = 0;
            line[line.size() - 14] = 1;
            line[line.size() - 15] = 1;
        }
        if (0x13 == cmd_num) {
            // PLESS sign
            line[line.size() - 13] = 1;
            line[line.size() - 14] = 0;
            line[line.size() - 15] = 0;
        }
        if (0x14 == cmd_num) {
            // OVERFLOW sign
            line[line.size() - 13] = 1;
            line[line.size() - 14] = 0;
            line[line.size() - 15] = 1;
        }

        std::unordered_map<std::string, std::size_t>::iterator iter_cline = jmp_address.find(result[1]);
        if (jmp_address.end() == iter_cline)
            throw std::invalid_argument("undefiend jump point: " + result[1]);
        std::size_t cline = iter_cline->second;

        // set current command
        line[line.size() - 17] = cline & 0x800ui16;
        line[line.size() - 18] = cline & 0x400ui16;
        line[line.size() - 19] = cline & 0x200ui16;
        line[line.size() - 20] = cline & 0x100ui16;
        line[line.size() - 21] = cline & 0x080ui16;
        line[line.size() - 22] = cline & 0x040ui16;
        line[line.size() - 23] = cline & 0x020ui16;
        line[line.size() - 24] = cline & 0x010ui16;
        line[line.size() - 25] = cline & 0x008ui16;
        line[line.size() - 26] = cline & 0x004ui16;
        line[line.size() - 27] = cline & 0x002ui16;
        line[line.size() - 28] = cline & 0x001ui16;

        command_line++;
    }

    return true;
}
const std::string base_logisim_rom = "v2.0 raw\n";

int main()
{
    bool base_path = true;
    std::string path_asm = "C:\\files\\avt\\merge.asm";
    std::string path_logisim = "C:\\files\\avt\\merge";
    std::string path_source;
    std::string path_end;

    try {
        if (base_path) {
            std::cout << "rewrite file " + path_logisim + "\nuse " + path_asm + " ?\n[y/n] >>";
            std::string user_choose;
            std::cin >> user_choose;
            if ("y" == user_choose) {
                path_source = path_asm;
                path_end = path_logisim;
                goto read_files;
            }
        }

        std::cout << "enter path source >> ";
        std::cin >> path_source;
        std::cout << "enter endpoint >> ";
        std::cin >> path_end;
    
    read_files:
        std::ifstream asmfile(path_source);
        if (!asmfile.is_open()) {
            std::cerr << "error: could not open the file " << path_source << std::endl;
            return 1;
        }
        std::ofstream logisimfile(path_end);
        if (!logisimfile.is_open()) {
            std::cerr << "error: could not open the file " << path_end << std::endl;
            return 1;
        }
        logisimfile << base_logisim_rom;

        std::string assembly_line;
        while (std::getline(asmfile, assembly_line)) {
            parse_file(assembly_line);
        }
        asmfile.clear();
        asmfile.seekg(0, std::ios::beg);
        command_line = 0;
        std::size_t cl = 0;
        while (std::getline(asmfile, assembly_line)) {
            if (readline(assembly_line)) {
                cl++;
                if (cl != command_line) {
                    std::cout << "???????????? on line " << all_line << std::endl;
                }
                std::cout << " --> " << to_hex_string(line) << std::endl;
                logisimfile << to_hex_string(line);
                logisimfile << " ";
            }
        }

        std::cout << "total lines: " << command_line << std::endl;
        std::cout << "total cl: " << cl << std::endl;
        std::cout << "end process...";
    }
    catch (std::exception e) {
        std::cerr << "error: " << e.what() << " on line " << all_line << std::endl;
    }

    return 0;
}
