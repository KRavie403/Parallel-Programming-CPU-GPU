#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <time.h>
#include "..\usr\include\GL\freeglut.h"

const int Dim = 1024;
int n = 1;
int num = 0;

// 사용자 정의 함수
void CreateTree();
void Tree(float x, float y, float angle, int n, float len);
void Timer(int id);

int main(int argc, char** argv)
{

	printf("차수:");
	scanf_s("%d", &num);
	// GLUT 초기화
	glutInit(&argc, argv);
	glutInitDisplayMode(GLUT_RGB);

	// 윈도우 크기 설정 및 생성
	glutInitWindowSize(Dim, Dim);
	glutCreateWindow("Fractal Tree (CPU)");

	// 콜백 함수 등록
	glutDisplayFunc(CreateTree);
	glutTimerFunc(300, Timer, 0);
	 

	// 이벤트 처리 루프 진입
	glutMainLoop();
	printf("Done");
	return 0;
}


void Timer(int id)
{
	glutPostRedisplay();
	glutTimerFunc(500, Timer, 0);
}


void CreateTree()
{
	if (n > num)
	{
		glClear(GL_COLOR_BUFFER_BIT);
		n = 1;
	}

	float x = 0.0f;			// 초기 x좌표
	float y = -1.0f;		// 초기 y좌표
	float angle = 0;		// 다음 트리로 향할때 변하는 각도변수
	float len = 0.3;		// 초기 트리 가지의 길이
	clock_t st = clock();
	Tree(x, y, angle, n, len);
	glFlush();
	printf("%d번째 차수의 Elaspsed time:%u ms\n",n, clock() - st);
	n++;
}

void Tree(float x, float y, float angle, int n, float len)
{
	float wid = (float)(num - n)/4;		// 가지의 너비를 점차줄임
	
	// RGB 값 계산
	float r = (float)0.5- 0.5 / n;		
	float g = (float)0.45 / n;
	float b = (float)0.12-0.12 / n;

	// 다음 트리가 향하는 좌표
	float x2 = x + len * sin(angle);
	float y2 = y + len * cos(angle);
	glColor3f(r, g, b);
	glLineWidth(wid);
	glBegin(GL_LINES);
	glVertex2f(x, y);
	glVertex2f(x2, y2);
	glEnd();
	
	// 다음 트리 생성을 위해 재귀함수로 호출
	if (n > 0)
	{
		Tree(x2, y2, angle + 25.5, n - 1, len * 0.8);
		Tree(x2, y2, angle - 25.5, n - 1, len * 0.8);
	}
}
	


